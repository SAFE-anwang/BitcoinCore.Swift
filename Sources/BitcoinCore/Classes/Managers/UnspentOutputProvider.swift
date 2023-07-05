class UnspentOutputProvider {
    let storage: IStorage
    let pluginManager: IPluginManager
    let confirmationsThreshold: Int

    private var confirmedUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0

        // Output must have a public key, that is, must belong to the user
        return storage.unspentOutputs()
                .filter({ unspentOutput in
                    // If a transaction is an outgoing transaction, then it can be used
                    // even if it's not included in a block yet
                    if unspentOutput.transaction.isOutgoing {
                        return true
                    }

                    // If a transaction is an incoming transaction, then it can be used
                    // only if it's included in a block and has enough number of confirmations
                    guard let blockHeight = unspentOutput.blockHeight else {
                        return false
                    }
                    
                    // Update for Safe
                    let str = "7361666573706f730100c2f824c4364195b71a1fcfa0a28ebae20f3501b21b08ae6d6ae8a3bca98ad9d64136e299eba2400183cd0a479e6350ffaec71bcaf0714a024d14183c1407805d75879ea2bf6b691214c372ae21939b96a695c746a6"
                    if let reserveHex = unspentOutput.output.reserve?.hs.hex {
                        if  reserveHex != "73616665", // 普通交易,
                            reserveHex != str,  // coinbase 收益,
                            !reserveHex.starts(with: "736166650100c9dcee22bb18bd289bca86e2c8bbb6487089adc9a13d875e538dd35c70a6bea42c0100000a02010012") {// safe备注，也是属于safe交易
                            return false
                        }
                    }

                    return blockHeight <= lastBlockHeight - confirmationsThreshold + 1
                })
    }

    private var unspendableUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return confirmedUtxo.filter {
            if let unlockedHeight = $0.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                return true
            }
            return !pluginManager.isSpendable(unspentOutput: $0)
        }
    }

    init(storage: IStorage, pluginManager: IPluginManager, confirmationsThreshold: Int) {
        self.storage = storage
        self.pluginManager = pluginManager
        self.confirmationsThreshold = confirmationsThreshold
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {

    var spendableUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0
        return confirmedUtxo.filter {
            if let unlockedHeight = $0.output.unlockedHeight, unlockedHeight > lastBlockHeight {
                return false
            }
            return pluginManager.isSpendable(unspentOutput: $0)
        }
    }

}

extension UnspentOutputProvider: IBalanceProvider {

    var balanceInfo: BalanceInfo {
        let spendable =  spendableUtxo.map { $0.output.value }.reduce(0, +)
        let unspendable = unspendableUtxo.map { $0.output.value }.reduce(0, +)

        return BalanceInfo(spendable: spendable, unspendable: unspendable)
    }

}
