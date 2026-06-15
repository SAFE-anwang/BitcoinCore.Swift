import BigInt
import Combine
import Foundation
import HdWalletKit
import HsExtensions

class DataProvider {
    private var cancellables = Set<AnyCancellable>()

    private let storage: IStorage
    private let balanceProvider: IBalanceProvider
    private let transactionInfoConverter: ITransactionInfoConverter
    // SAFE 专用过滤回调：仅在 SAFE 网络下由 BitcoinCoreBuilder 注入。
    // 非 SAFE 网络传 nil，对其他 token 的查询路径零影响。
    private let transactionFilter: ((FullTransactionForInfo) -> Bool)?

    private let balanceUpdateSubject = PassthroughSubject<Void, Never>()

    public var balance: BalanceInfo {
        didSet {
            if !(oldValue == balance) {
                delegate?.balanceUpdated(balance: balance)
            }
        }
    }

    private let lastBlockInfoQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.data-provider.last-block-info", qos: .utility)
    private var _lastBlockInfo: BlockInfo?

    weak var delegate: IDataProviderDelegate?

    init(storage: IStorage, balanceProvider: IBalanceProvider, transactionInfoConverter: ITransactionInfoConverter, throttleTimeMilliseconds: Int = 500, transactionFilter: ((FullTransactionForInfo) -> Bool)? = nil) {
        self.storage = storage
        self.balanceProvider = balanceProvider
        self.transactionInfoConverter = transactionInfoConverter
        self.transactionFilter = transactionFilter
        balance = balanceProvider.balanceInfo
        _lastBlockInfo = storage.lastBlock.map { blockInfo(fromBlock: $0) }

        balanceUpdateSubject
            .throttle(for: .milliseconds(throttleTimeMilliseconds), scheduler: DispatchQueue.global(qos: .background), latest: true)
            .sink { [weak self] in
                self?.balance = balanceProvider.balanceInfo
            }
            .store(in: &cancellables)
    }

    private func blockInfo(fromBlock block: Block) -> BlockInfo {
        BlockInfo(
            headerHash: block.headerHash.hs.reversedHex,
            height: block.height,
            timestamp: block.timestamp
        )
    }
}

extension DataProvider: IBlockchainDataListener {
    func onUpdate(updated: [Transaction], inserted: [Transaction], inBlock block: Block?) {
        // 流式插入路径是同步时最热的路径：必须复用 transactionFilter，
        // 避免大量 SAFE3 锁仓/找零交易被 fullInfo + transactionInfo 全量转换后上抛 delegate，
        // 导致 UI 在主线程上做大批 diff/渲染卡顿。
        //
        // 过滤下推：
        // 1. 优先调用 ISafe3FilteredStorage.fullInfo(...filter:)，让 GrdbStorage 在 JOIN
        //    input/output/metadata 之前就在 SQL 层把不可见交易剔除。
        // 2. 若 storage 未实现 ISafe3FilteredStorage（自定义 IStorage），则在拿到 fullInfo
        //    之后用 transactionFilter 闭包在内存里二次过滤。
        // 3. 非 SAFE 网络（transactionFilter == nil）走原版路径，零额外开销。
        let insertedInfo = filteredFullInfo(forTransactions: inserted.map { TransactionWithBlock(transaction: $0, blockHeight: block?.height) })
        let updatedInfo  = filteredFullInfo(forTransactions: updated.map  { TransactionWithBlock(transaction: $0, blockHeight: block?.height) })

        delegate?.transactionsUpdated(
            inserted: insertedInfo.map { transactionInfoConverter.transactionInfo(fromTransaction: $0) },
            updated:  updatedInfo.map  { transactionInfoConverter.transactionInfo(fromTransaction: $0) }
        )

        balanceProvider.invalidateCache()    // 交易更新后失效缓存，下次 balanceInfo 重新计算
        balanceUpdateSubject.send()
    }

    /// 把 SAFE3 过滤下推到存储层（ISafe3FilteredStorage 实现）；未实现则 fall back 到
    /// 内存里 filter。两种路径对调用方完全透明。
    private func filteredFullInfo(forTransactions transactionsWithBlocks: [TransactionWithBlock]) -> [FullTransactionForInfo] {
        // 非 SAFE 网络（无 filter）→ 走原版方法，零额外开销
        guard let filter = transactionFilter else {
            return storage.fullInfo(forTransactions: transactionsWithBlocks)
        }
        // SAFE 网络：
        // 1) 优先用 ISafe3FilteredStorage（GrdbStorage）下推到 SQL
        // 2) 退路：调用原版 fullInfo 后在内存里 filter
        let filterKind: TransactionFilterKind = .safe3ReserveOnly
        if let safe3Storage = storage as? ISafe3FilteredStorage {
            return safe3Storage.fullInfo(forTransactions: transactionsWithBlocks, transactionFilterKind: filterKind)
        }
        let rawInfo = storage.fullInfo(forTransactions: transactionsWithBlocks)
        return rawInfo.filter(filter)
    }

    func onDelete(transactionHashes: [String]) {
        // onDelete 只转发 hash，由 delegate 端负责去重/移除。
        // 若一笔交易在 onUpdate 阶段被 filter 剔除，hash 不会进入 delegate 视图，
        // 这里的删除就是 no-op，无需额外过滤。
        delegate?.transactionsDeleted(hashes: transactionHashes)

        balanceProvider.invalidateCache()    // 交易删除后失效缓存
        balanceUpdateSubject.send()
    }

    func onInsert(block: Block) {
        if block.height > (lastBlockInfo?.height ?? 0) {
            let lastBlockInfo = blockInfo(fromBlock: block)

            lastBlockInfoQueue.async {
                self._lastBlockInfo = lastBlockInfo
            }

            delegate?.lastBlockInfoUpdated(lastBlockInfo: lastBlockInfo)

            balanceProvider.invalidateCache()    // 新区块插入后失效缓存
            balanceUpdateSubject.send()
        }
    }
}

extension DataProvider: IDataProvider {

    var lastBlockInfo: BlockInfo? {
        lastBlockInfoQueue.sync {
            _lastBlockInfo
        }
    }

    func transactions(fromUid: String?, type: TransactionFilterType?, descending: Bool, limit: Int?) -> [TransactionInfo] {
        var resolvedTimestamp: Int? = nil
        var resolvedOrder: Int? = nil

        if let fromUid, let transaction = storage.validOrInvalidTransaction(byUid: fromUid) {
            resolvedTimestamp = transaction.timestamp
            resolvedOrder = transaction.order
        }

        // 分页 + SAFE3 过滤：
        // - 优先通过 ISafe3FilteredStorage 在 SQL 层完成 reserve 过滤（分页窗口里就过滤），
        //   避免拉 limit 条 fullInfo JOIN 后再在内存里把 SAFE3 锁仓交易剔除导致少条目/空页。
        // - limit 不再翻倍：SQL 层在拉取时已确保窗口里都是可见交易，返回 N 条时 N == limit。
        // - 非 SAFE 网络（无 transactionFilter）走 .none 路径，行为与原版完全一致。
        let filterKind: TransactionFilterKind = (transactionFilter != nil) ? .safe3ReserveOnly : .none

        let transactions: [FullTransactionForInfo]
        if let safe3Storage = storage as? ISafe3FilteredStorage {
            transactions = safe3Storage.validOrInvalidTransactionsFullInfo(
                fromTimestamp: resolvedTimestamp,
                fromOrder: resolvedOrder,
                descending: descending,
                type: type,
                limit: limit,
                transactionFilterKind: filterKind
            )
        } else {
            // 退路：自定义 IStorage 未实现 ISafe3FilteredStorage。
            // SQL 不下推 → 必须在内存里二次过滤。这里会出现一个边界问题：
            //  原 storage 拉 limit 条数据，内存 filter 后可能只剩 N < limit 条
            //  （SAFE3 锁仓交易被裁掉），结果页不足 limit，看起来像"少条目/空页"。
            //
            // 修复：仅当 transactionFilter != nil 时把 limit 翻倍拉（2*limit），
            //      内存过滤后再用 prefix 截到原 limit，保证窗口"满页"且与 SAFE 网络
            //      SQL 下推路径的可见集合一致。
            // - 非 SAFE3 token：transactionFilter == nil → effectiveLimit == limit，
            //   走原版 raw 路径不截断，行为与原版完全一致，零额外开销。
            // - SAFE3 + 自定义 IStorage（未实现 ISafe3FilteredStorage）：
            //   翻倍 + 截断 → 满页 + 过滤语义等价。
            let needsWindowCompensation = (transactionFilter != nil && limit != nil)
            let effectiveLimit: Int? = needsWindowCompensation ? (limit! * 2) : limit
            let raw = storage.validOrInvalidTransactionsFullInfo(
                fromTimestamp: resolvedTimestamp,
                fromOrder: resolvedOrder,
                descending: descending,
                type: type,
                limit: effectiveLimit
            )
            if let transactionFilter = transactionFilter {
                let filtered = raw.filter(transactionFilter)
                // needsWindowCompensation 时窗口已翻倍，截到 limit 保证行为稳定
                // （分页时原 storage 的 limit 由调用方决定，DataProvider 不擅自改变 limit 语义）。
                transactions = needsWindowCompensation ? Array(filtered.prefix(limit!)) : filtered
            } else {
                transactions = raw
            }
        }

        return transactions.map { transactionInfoConverter.transactionInfo(fromTransaction: $0) }
    }

    func transaction(hash: String) -> TransactionInfo? {
        guard let hash = hash.reversedData else {
            return nil
        }

        guard let transactionFullInfo = storage.transactionFullInfo(byHash: hash) else {
            return nil
        }

        return transactionInfoConverter.transactionInfo(fromTransaction: transactionFullInfo)
    }

    func transactionInfo(from fullInfo: FullTransactionForInfo) -> TransactionInfo {
        transactionInfoConverter.transactionInfo(fromTransaction: fullInfo)
    }

    func debugInfo(network _: INetwork, scriptType: ScriptType, addressConverter: IAddressConverter) -> String {
        var lines = [String]()

        let pubKeys = storage.publicKeys().sorted(by: { $0.index < $1.index })

        for pubKey in pubKeys {
            lines.append("acc: \(pubKey.account) - inx: \(pubKey.index) - ext: \(pubKey.external) : \((try! addressConverter.convert(publicKey: pubKey, type: scriptType)).stringValue)")
        }
        lines.append("PUBLIC KEYS COUNT: \(pubKeys.count)")
        return lines.joined(separator: "\n")
    }

    func rawTransaction(transactionHash: String) -> String? {
        guard let hash = transactionHash.reversedData else {
            return nil
        }

        return storage.transactionFullInfo(byHash: hash)?.rawTransaction ??
            storage.invalidTransaction(byHash: hash)?.rawTransaction
    }    
    func updateLastBlockInfo() {
        _lastBlockInfo = storage.lastBlock.map { blockInfo(fromBlock: $0) }
    }
    
}
