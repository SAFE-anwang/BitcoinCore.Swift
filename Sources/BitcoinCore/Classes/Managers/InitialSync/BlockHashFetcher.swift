class BlockHashFetcher {
    weak var listener: IApiSyncListener?

    private let restoreKeyConverter: IRestoreKeyConverter
    private let apiManager: ISyncTransactionApi
    private let helper: IBlockHashFetcherHelper

    init(restoreKeyConverter: IRestoreKeyConverter, apiManager: ISyncTransactionApi, helper: IBlockHashFetcherHelper) {
        self.restoreKeyConverter = restoreKeyConverter
        self.apiManager = apiManager
        self.helper = helper
    }

}

extension BlockHashFetcher: IBlockHashFetcher {

    func getBlockHashes(externalKeys: [PublicKey], internalKeys: [PublicKey]) async throws -> BlockHashesResponse {
        let externalAddresses = externalKeys.map {
            restoreKeyConverter.keysForApiRestore(publicKey: $0)
        }

        let internalAddresses = internalKeys.map {
            restoreKeyConverter.keysForApiRestore(publicKey: $0)
        }

        let allAddresses = externalAddresses.flatMap { $0 } + internalAddresses.flatMap { $0 }
        let transactionResponses = try await apiManager.transactions(addresses: allAddresses)

        if transactionResponses.isEmpty {
            return BlockHashesResponse(blockHashes: [], externalLastUsedIndex: -1, internalLastUsedIndex: -1)
        }

        listener?.transactionsFound(count: transactionResponses.count)

        let outputs = transactionResponses.flatMap { $0.txOutputs }
        let externalLastUsedIndex = helper.lastUsedIndex(addresses: externalAddresses, outputs: outputs)
        let internalLastUsedIndex = helper.lastUsedIndex(addresses: internalAddresses, outputs: outputs)

        let blockHashes: [BlockHash] = transactionResponses.compactMap {
            BlockHash(headerHashReversedHex: $0.blockHash, height: $0.blockHeight, sequence: 0)
        }

        return BlockHashesResponse(blockHashes: blockHashes, externalLastUsedIndex: externalLastUsedIndex, internalLastUsedIndex: internalLastUsedIndex)
    }

}

struct BlockHashesResponse {
    let blockHashes: [BlockHash]
    let externalLastUsedIndex: Int
    let internalLastUsedIndex: Int
}
