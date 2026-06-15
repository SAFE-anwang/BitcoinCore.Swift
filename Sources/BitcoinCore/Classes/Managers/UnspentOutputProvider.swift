import UIKit
class UnspentOutputProvider {
    let storage: IStorage
    let pluginManager: IPluginManager
    let confirmationsThreshold: Int

    /// SAFE3 reserve 过滤开关。默认 false（保持原版行为，对所有 token 兼容）。
    /// 仅在 SAFE 网络由 BitcoinCoreBuilder 注入 true，避免对其他 token 产生副作用。
    let enableSafe3ReserveFilter: Bool

    // Cache for allUtxo. Keyed by lastBlock.height — a same-height query returns
    // the same set of confirmed incoming + all outgoing unspent outputs (modulo
    // mempool-only changes which we accept as eventual-consistency).
    // Lock-step serialization via cacheQueue; allUtxo is touched from multiple
    // threads (DataProvider throttle sink, UI/business layer, send flow).
    private let cacheQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.unspent-output-cache", qos: .userInitiated)
    private var cachedAllUtxo: [UnspentOutput]?
    private var cachedLastBlockHeight: Int = -1   // -1 = cache invalid

    // Confirmed incoming and all outgoing unspent outputs.
    // 缓存策略：以 lastBlock.height 作为版本号。同一次"逻辑刷新"中多个属性访问
    // (balance / spendableUtxo / unspendableTimeLockedUtxo) 共享同一次 SQL 结果。
    // 状态变化时由 DataProvider 显式调 invalidateCache() 失效。
    //
    // lastBlockHeight 必须由调用方传入：filter 和调用方的分类逻辑必须用同一个值，
    // 否则在 lastBlock 变化的瞬间，filter 用 height=N+1 而分类用 height=N 会导致
    // 余额误判（边界 UTXO 错误归类）。
    private func allUtxo(lastBlockHeight: Int) -> [UnspentOutput] {
        return cacheQueue.sync {
            if let cached = cachedAllUtxo, cachedLastBlockHeight == lastBlockHeight {
                return cached
            }
            let utxos = storage.unspentOutputs()
                .filter { unspentOutput in
                    // If a transaction is an outgoing transaction, then it can be used
                    // even if it's not included in a block yet
                    if unspentOutput.transaction.isOutgoing {
                        return true
                    }

                    // 开启 SAFE3 reserve 过滤后，非 outgoing 交易必须满足：
                    // 1. 所有 output 都是 SAFE3 reserve（包含 plainSafe、coinbaseSafe、memoSafe）
                    // 2. 已确认（blockHeight 满足 confirmations 阈值）
                    if enableSafe3ReserveFilter {
                        guard Safe3OutputFilter.isSafe3Reserve(unspentOutput.output.reserve) else {
                            return false
                        }
                    }

                    guard let blockHeight = unspentOutput.blockHeight else {
                        return false
                    }

                    return blockHeight <= lastBlockHeight - confirmationsThreshold + 1
                }
            cachedAllUtxo = utxos
            cachedLastBlockHeight = lastBlockHeight
            return utxos
        }
    }

    private var unspendableUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return allUtxo(lastBlockHeight: lastBlockHeight).filter {
            if let unlockedHeight = $0.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                return true
            }
            return !pluginManager.isSpendable(unspentOutput: $0) || $0.transaction.status != .relayed
        }
    }

    var unspendableTimeLockedUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return allUtxo(lastBlockHeight: lastBlockHeight).filter {
            if let unlockedHeight = $0.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                return true
            }
            return !pluginManager.isSpendable(unspentOutput: $0)
        }
    }

    private var unspendableNotRelayedUtxo: [UnspentOutput] {
        allUtxo(lastBlockHeight: storage.lastBlock?.height ?? 0).filter { $0.transaction.status != .relayed }
    }

    init(storage: IStorage, pluginManager: IPluginManager, confirmationsThreshold: Int, enableSafe3ReserveFilter: Bool = false) {
        self.storage = storage
        self.pluginManager = pluginManager
        self.confirmationsThreshold = confirmationsThreshold
        self.enableSafe3ReserveFilter = enableSafe3ReserveFilter
    }

    /// 显式失效缓存。调用方应在底层数据发生变更后调用：
    /// - 新区块插入
    /// - 交易新增 / 更新 / 删除
    /// 不调用则缓存按 lastBlock.height 自然失效（高度变化时重算）。
    func invalidateCache() {
        cacheQueue.sync {
            cachedAllUtxo = nil
            cachedLastBlockHeight = -1
        }
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {
    var spendableUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return allUtxo(lastBlockHeight: lastBlockHeight).filter {
            if let unlockedHeight = $0.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                return false
            }
            return pluginManager.isSpendable(unspentOutput: $0) && $0.transaction.status == .relayed
        }
    }

    func spendableUtxo(filters: UtxoFilters) -> [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return allUtxo(lastBlockHeight: lastBlockHeight).filter { utxo in
            guard pluginManager.isSpendable(unspentOutput: utxo), utxo.transaction.status == .relayed else {
                return false
            }

            if let scriptTypes = filters.scriptTypes, !scriptTypes.contains(utxo.output.scriptType) {
                return false
            }

            if let outputsCount = filters.maxOutputsCountForInputs,
               storage.outputsCount(transactionHash: utxo.transaction.dataHash) > outputsCount
            {
                return false
            }

            return true
        }
    }

    // Only confirmed spendable outputs
    func confirmedSpendableUtxo(filters: UtxoFilters) -> [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0

        return spendableUtxo(filters: filters)
            .filter { unspentOutput in
                guard let blockHeight = unspentOutput.blockHeight else {
                    return false
                }

                return blockHeight <= lastBlockHeight - confirmationsThreshold + 1
            }
    }
}

extension UnspentOutputProvider: IBalanceProvider {
    var balanceInfo: BalanceInfo {
        var spendable = 0
        var unspendableTimeLocked = 0
        var unspendableNotRelayed = 0

        // 复用 allUtxo 一次遍历：它已经过滤了 outgoing / safe3 reserve / confirmed，
        // 避免再单独调一次 storage.unspentOutputs()（那是 O(N×M) 全表扫描）。
        // lastBlockHeight 提到外层共享，传给 allUtxo 内部 filter 使用同一个值：
        // 防止 lastBlock 在两次读取之间变化导致余额误判。
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        let utxos = allUtxo(lastBlockHeight: lastBlockHeight)

        // 恢复与原版 balanceInfo 完全一致的口径（isOutgoing 不再是 spendable 的充分条件）：
        //  - spendable:             isSpendable && status == .relayed
        //                           （对应原版 spendableUtxo(filters: UtxoFilters())，与 filters
        //                            版本一致：不检查 unlockedHeight）
        //  - unspendableTimeLocked: unlockedHeight > lastBlock || !isSpendable
        //                           （对应原版 unspendableTimeLockedUtxo）
        //  - unspendableNotRelayed: status != .relayed
        //                           （对应原版 unspendableNotRelayedUtxo）
        // 三类集合与原版一样不互斥：同一笔 UTXO 可能落入多个桶（例如 outgoing + 时间锁
        // + 不可花费 → 同时计入 unspendableTimeLocked 与 unspendableNotRelayed）。
        // 这是原版的既有行为，不应修改以保持兼容。
        for unspentOutput in utxos {
            if pluginManager.isSpendable(unspentOutput: unspentOutput) && unspentOutput.transaction.status == .relayed {
                spendable += unspentOutput.output.value
            }
            if let unlockedHeight = unspentOutput.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                unspendableTimeLocked += unspentOutput.output.value
            } else if !pluginManager.isSpendable(unspentOutput: unspentOutput) {
                unspendableTimeLocked += unspentOutput.output.value
            }
            if unspentOutput.transaction.status != .relayed {
                unspendableNotRelayed += unspentOutput.output.value
            }
        }

        return BalanceInfo(spendable: spendable, unspendableTimeLocked: unspendableTimeLocked, unspendableNotRelayed: unspendableNotRelayed)
    }
}
