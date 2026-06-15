import Foundation
@testable import BitcoinCore

/// 共享的测试用 stub：覆盖 IStorage / IPluginManager / IBalanceProvider /
/// ITransactionInfoConverter / IDataProviderDelegate 五个协议中测试需要的最小集合。
///
/// 不依赖 Cuckoo/Quick/Nimble，每个 stub 都独立实现 protocol requirement；
/// 未被 override 的方法 / 属性会触发 fatalError，确保"用不到的没被静默调用"。
///
/// 注意：本文件只在 test target 编译，不会影响 production 代码。

// MARK: - IStorage Stub

/// 基础 IStorage stub：所有方法都抛 fatalError。子类覆盖需要的部分。
class StubIStorage: IStorage {
    func previousOutput(ofInput input: Input) -> Output? { fatalError("StubIStorage.previousOutput(ofInput:) not implemented") }
    func outputsWithPublicKeys() -> [OutputWithPublicKey] { fatalError("StubIStorage.outputsWithPublicKeys() not implemented") }
    var initialRestored: Bool? { nil }
    func set(initialRestored: Bool) { fatalError("StubIStorage.set(initialRestored:) not implemented") }
    func leastScoreFastestPeerAddress(excludingIps: [String]) -> PeerAddress? { fatalError("not implemented") }
    func leastScoreFastestPeerAddressSafe(excludingIps: [String]) -> PeerAddress? { fatalError("not implemented") }
    func peerAddressExist(address: String) -> Bool { fatalError("not implemented") }
    func save(peerAddresses: [PeerAddress]) { fatalError("not implemented") }
    func saveLastBlock(ip: String, lastBlock: Int32) { fatalError("not implemented") }
    func deletePeerAddress(byIp ip: String) throws { fatalError("not implemented") }
    func set(connectionTime: Double, toPeerAddress ip: String) { fatalError("not implemented") }
    var apiBlockHashesCount: Int { fatalError("not implemented") }
    var blockchainBlockHashes: [BlockHash] { [] }
    var lastBlockchainBlockHash: BlockHash? { nil }
    func blockHashHeaderHashes(except excludedHashes: [Data]) -> [Data] { [] }
    var blockHashHeaderHashes: [Data] { [] }
    var lastBlockHash: BlockHash? { nil }
    var blockHashPublicKeys: [BlockHashPublicKey] { [] }
    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash] { [] }
    func add(blockHashes: [BlockHash]) { fatalError("not implemented") }
    func add(blockHashPublicKeys: [BlockHashPublicKey]) { fatalError("not implemented") }
    func deleteBlockHash(byHash hash: Data) { fatalError("not implemented") }
    func deleteBlockchainBlockHashes() { fatalError("not implemented") }
    func deleteUselessBlocks(before height: Int) { fatalError("not implemented") }
    func releaseMemory() { }
    var blocksCount: Int { 0 }

    /// 改为可写的 stored property，让测试 setUp 可以直接 `storage.lastBlock = ...`。
    /// 默认 nil；子类的 CountingStorage 仍可基于 lastBlockOverride 做调用计数埋点。
    var lastBlock: Block? = nil

    var downloadedTransactionsBestBlockHeight: Int { 0 }
    func blocksCount(headerHashes: [Data]) -> Int { 0 }
    func update(block: Block) { fatalError("not implemented") }
    func save(block: Block) { fatalError("not implemented") }
    func blocks(heightGreaterThan leastHeight: Int, sortedBy sortField: Block.Columns, limit: Int) -> [Block] { [] }
    func blocks(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Block] { [] }
    func blocks(byHexes hexes: [Data]) -> [Block] { [] }
    func blocks(heightGreaterThanOrEqualTo height: Int, stale: Bool) -> [Block] { [] }
    func blocks(stale: Bool) -> [Block] { [] }
    func blockByHeightStalePrioritized(height: Int) -> Block? { nil }
    func block(byHeight height: Int) -> Block? { nil }
    func block(byHash hash: Data) -> Block? { nil }
    func block(stale: Bool, sortedHeight: String) -> Block? { nil }
    func add(block: Block) throws { fatalError("not implemented") }
    func setBlockPartial(hash: Data) throws { fatalError("not implemented") }
    func delete(blocks: [Block]) throws { fatalError("not implemented") }
    func unstaleAllBlocks() throws { fatalError("not implemented") }
    func timestamps(from startHeight: Int, to endHeight: Int) -> [Int] { [] }
    func transactionExists(byHash hash: Data) -> Bool { false }
    func fullTransaction(byHash hash: Data) -> FullTransaction? { nil }
    func transaction(byHash hash: Data) -> Transaction? { nil }
    func invalidTransaction(byHash hash: Data) -> InvalidTransaction? { nil }
    func validOrInvalidTransaction(byUid uid: String) -> Transaction? { nil }
    func incomingPendingTransactionHashes() -> [Data] { [] }
    func incomingPendingTransactionsExist() -> Bool { false }
    func inputs(byHashes hashes: [Data]) -> [Input] { [] }
    func transactions(ofBlock block: Block) -> [Transaction] { [] }
    func transactions(hashes: [Data]) -> [Transaction] { [] }
    func fullTransactions(from transactions: [Transaction]) -> [FullTransaction] { [] }
    func descendantTransactionsFullInfo(of transactionHash: Data) -> [FullTransactionForInfo] { [] }
    func descendantTransactions(of transactionHash: Data) -> [Transaction] { [] }
    func newTransactions() -> [FullTransaction] { [] }
    func newTransaction(byHash hash: Data) -> Transaction? { nil }
    func relayedTransactionExists(byHash hash: Data) -> Bool { false }
    func add(transaction: FullTransaction) throws { fatalError("not implemented") }
    func update(transaction: FullTransaction) throws { fatalError("not implemented") }
    func update(transaction: Transaction) throws { fatalError("not implemented") }
    func fullInfo(forTransactions transactionsWithBlocks: [TransactionWithBlock]) -> [FullTransactionForInfo] {
        fatalError("StubIStorage.fullInfo(forTransactions:) not implemented")
    }
    func validOrInvalidTransactionsFullInfo(fromTimestamp: Int?, fromOrder: Int?, descending: Bool, type: TransactionFilterType?, limit: Int?) -> [FullTransactionForInfo] {
        fatalError("StubIStorage.validOrInvalidTransactionsFullInfo(...) not implemented")
    }
    func transactionFullInfo(byHash hash: Data) -> FullTransactionForInfo? { nil }
    func moveTransactionsTo(invalidTransactions: [InvalidTransaction]) throws { fatalError("not implemented") }
    func move(invalidTransaction: InvalidTransaction, toTransactions transaction: FullTransaction) throws { fatalError("not implemented") }
    func unspentOutputs() -> [UnspentOutput] { fatalError("StubIStorage.unspentOutputs() not implemented") }
    func inputs(transactionHash: Data) -> [Input] { [] }
    func outputs(transactionHash: Data) -> [Output] { [] }
    func outputsCount(transactionHash: Data) -> Int { 0 }
    func inputsUsingOutputs(withTransactionHash transactionHash: Data) -> [Input] { [] }
    func inputsUsing(previousOutputTxHash: Data, previousOutputIndex: Int) -> [Input] { [] }
    func sentTransaction(byHash hash: Data) -> SentTransaction? { nil }
    func update(sentTransaction: SentTransaction) { fatalError("not implemented") }
    func delete(sentTransaction: SentTransaction) { fatalError("not implemented") }
    func add(sentTransaction: SentTransaction) { fatalError("not implemented") }
    func publicKeys() -> [PublicKey] { [] }
    func publicKey(raw: Data) -> PublicKey? { nil }
    func publicKey(hashP2pkh: Data) -> PublicKey? { nil }
    func publicKey(hashP2wpkhWrappedInP2sh: Data) -> PublicKey? { nil }
    func publicKey(convertedForP2tr: Data) -> PublicKey? { nil }
    func add(publicKeys: [PublicKey]) { fatalError("not implemented") }
    func publicKeysWithUsedState() -> [PublicKeyWithUsedState] { [] }
    func publicKey(byPath path: String) -> PublicKey? { nil }
}

// MARK: - IPluginManager Stub

/// 始终返回 isSpendable=true 的最简 stub。
class AllowAllPluginManager: IPluginManager {
    func validate(address: Address, pluginData: [UInt8: IPluginData]) throws { }
    func maxSpendLimit(pluginData: [UInt8: IPluginData]) throws -> Int? { nil }
    func add(plugin: IPlugin) { }
    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [UInt8: IPluginData], skipChecks: Bool) throws { }
    func processInputs(mutableTransaction: MutableTransaction) throws { }
    func processTransactionWithNullData(transaction: FullTransaction, nullDataOutput: Output) throws { }
    func isSpendable(unspentOutput: UnspentOutput) -> Bool { true }
    func parsePluginData(fromPlugin: UInt8, pluginDataString: String, transactionTimestamp: Int) -> IPluginOutputData? { nil }
    func incrementedSequence(of input: InputWithPreviousOutput) -> Int { 0 }
}

// MARK: - IBalanceProvider Stub

class StubBalanceProvider: IBalanceProvider {
    var balanceInfoValue: BalanceInfo = BalanceInfo(spendable: 0, unspendableTimeLocked: 0, unspendableNotRelayed: 0)
    var invalidateCacheCallCount = 0
    var balanceInfo: BalanceInfo { balanceInfoValue }
    func invalidateCache() { invalidateCacheCallCount += 1 }
}

// MARK: - ITransactionInfoConverter Stub

class StubTransactionInfoConverter: ITransactionInfoConverter {
    var baseTransactionInfoConverter: IBaseTransactionInfoConverter! = nil
    var infos: [FullTransactionForInfo] = []
    func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo {
        infos.append(transactionForInfo)
        let tx = transactionForInfo.transactionWithBlock.transaction
        return TransactionInfo(
            uid: tx.uid,
            transactionHash: tx.dataHash.hs.reversedHex,
            transactionIndex: tx.order,
            inputs: [],
            outputs: [],
            amount: 0,
            type: .incoming,
            fee: nil,
            blockHeight: transactionForInfo.transactionWithBlock.blockHeight,
            timestamp: tx.timestamp,
            status: tx.status,
            conflictingHash: nil,
            rbfEnabled: false
        )
    }
}

// MARK: - IDataProviderDelegate Stub

class StubDataProviderDelegate: IDataProviderDelegate {
    var inserted: [TransactionInfo] = []
    var updated: [TransactionInfo] = []
    var deleted: [String] = []
    var balanceUpdates: [BalanceInfo] = []
    var lastBlockUpdates: [BlockInfo] = []

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        self.inserted.append(contentsOf: inserted)
        self.updated.append(contentsOf: updated)
    }
    func transactionsDeleted(hashes: [String]) {
        self.deleted.append(contentsOf: hashes)
    }
    func balanceUpdated(balance: BalanceInfo) {
        balanceUpdates.append(balance)
    }
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockUpdates.append(lastBlockInfo)
    }
}
