import BigInt
import Combine
import Foundation
import HsToolKit
import NIO

enum BlockValidatorType { case header, bits, legacy, testNet, EDA, DAA, DGW }

protocol IPublicKeyFetcher {
    func publicKeys(indices: Range<UInt32>, external: Bool) throws -> [PublicKey]
}

public protocol IDifficultyEncoder {
    func compactFrom(hash: Data) -> Int
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

public protocol IBlockValidatorHelper {
    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

public protocol IBlockValidator: AnyObject {
    func validate(block: Block, previousBlock: Block) throws
}

public protocol IBlockChainedValidator: IBlockValidator {
    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool
}

protocol IHDWallet {
    func publicKey(account: Int, index: Int, external: Bool) throws -> PublicKey
    func publicKeys(account: Int, indices: Range<UInt32>, external: Bool) throws -> [PublicKey]
}

protocol IPrivateHDWallet {
    func privateKeyData(account: Int, index: Int, external: Bool) throws -> Data
}

protocol IApiConfigProvider {
    var reachabilityHost: String { get }
    var apiUrl: String { get }
}

protocol IPeerAddressManager: AnyObject {
    var delegate: IPeerAddressManagerDelegate? { get set }
    var ip: String? { get }
    var hasFreshIps: Bool { get }
    func markSuccess(ip: String)
    func markFailed(ip: String)
    func add(ips: [String])
    func markConnected(peer: IPeer)
    func saveLastBlock(ip: String, lastBlock: Int32) // safe
}

protocol IApiSyncStateManager: AnyObject {
    var restored: Bool { get set }
}

protocol IBlockDiscovery {
    func discoverBlockHashes() async throws -> ([PublicKey], [BlockHash])
    func updateMaxHeight(maxHeight: Int)
}

public protocol IOutputStorage {
    func previousOutput(ofInput: Input) -> Output?
    func outputsWithPublicKeys() -> [OutputWithPublicKey]
}

public protocol IStorage: IOutputStorage {
    var initialRestored: Bool? { get }
    func set(initialRestored: Bool)

    func leastScoreFastestPeerAddress(excludingIps: [String]) -> PeerAddress?
    func leastScoreFastestPeerAddressSafe(excludingIps: [String]) -> PeerAddress? // safe
    func peerAddressExist(address: String) -> Bool
    func save(peerAddresses: [PeerAddress])
    func saveLastBlock(ip: String, lastBlock: Int32) // safe
    func deletePeerAddress(byIp ip: String) throws
    func set(connectionTime: Double, toPeerAddress: String)

    var apiBlockHashesCount: Int { get }
    var blockchainBlockHashes: [BlockHash] { get }
    var lastBlockchainBlockHash: BlockHash? { get }
    func blockHashHeaderHashes(except: [Data]) -> [Data]
    var blockHashHeaderHashes: [Data] { get }
    var lastBlockHash: BlockHash? { get }
    var blockHashPublicKeys: [BlockHashPublicKey] { get }
    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash]
    func add(blockHashes: [BlockHash])
    func add(blockHashPublicKeys: [BlockHashPublicKey])
    func deleteBlockHash(byHash: Data)
    func deleteBlockchainBlockHashes()
    func deleteUselessBlocks(before: Int)
    func releaseMemory()

    var blocksCount: Int { get }
    var lastBlock: Block? { get }
    var downloadedTransactionsBestBlockHeight: Int { get }
    func blocksCount(headerHashes: [Data]) -> Int
    func update(block: Block)
    func save(block: Block)
    func blocks(heightGreaterThan: Int, sortedBy: Block.Columns, limit: Int) -> [Block]
    func blocks(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Block]
    func blocks(byHexes: [Data]) -> [Block]
    func blocks(heightGreaterThanOrEqualTo: Int, stale: Bool) -> [Block]
    func blocks(stale: Bool) -> [Block]
    func blockByHeightStalePrioritized(height: Int) -> Block?
    func block(byHeight: Int) -> Block?
    func block(byHash: Data) -> Block?
    func block(stale: Bool, sortedHeight: String) -> Block?
    func add(block: Block) throws
    func setBlockPartial(hash: Data) throws
    func delete(blocks: [Block]) throws
    func unstaleAllBlocks() throws
    func timestamps(from startHeight: Int, to endHeight: Int) -> [Int]

    func transactionExists(byHash: Data) -> Bool
    func fullTransaction(byHash hash: Data) -> FullTransaction?
    func transaction(byHash: Data) -> Transaction?
    func invalidTransaction(byHash: Data) -> InvalidTransaction?
    func validOrInvalidTransaction(byUid: String) -> Transaction?
    func incomingPendingTransactionHashes() -> [Data]
    func incomingPendingTransactionsExist() -> Bool
    func inputs(byHashes hashes: [Data]) -> [Input]
    func transactions(ofBlock: Block) -> [Transaction]
    func transactions(hashes: [Data]) -> [Transaction]
    func fullTransactions(from: [Transaction]) -> [FullTransaction]
    func descendantTransactionsFullInfo(of transactionHash: Data) -> [FullTransactionForInfo]
    func descendantTransactions(of transactionHash: Data) -> [Transaction]
    func newTransactions() -> [FullTransaction]
    func newTransaction(byHash: Data) -> Transaction?
    func relayedTransactionExists(byHash: Data) -> Bool
    func add(transaction: FullTransaction) throws
    func update(transaction: FullTransaction) throws
    func update(transaction: Transaction) throws
    func fullInfo(forTransactions: [TransactionWithBlock]) -> [FullTransactionForInfo]
    func validOrInvalidTransactionsFullInfo(fromTimestamp: Int?, fromOrder: Int?, descending: Bool, type: TransactionFilterType?, limit: Int?) -> [FullTransactionForInfo]
    func transactionFullInfo(byHash hash: Data) -> FullTransactionForInfo?
    func moveTransactionsTo(invalidTransactions: [InvalidTransaction]) throws
    func move(invalidTransaction: InvalidTransaction, toTransactions: FullTransaction) throws

    func unspentOutputs() -> [UnspentOutput]
    func inputs(transactionHash: Data) -> [Input]
    func outputs(transactionHash: Data) -> [Output]
    func outputsCount(transactionHash: Data) -> Int
    func inputsUsingOutputs(withTransactionHash: Data) -> [Input]
    func inputsUsing(previousOutputTxHash: Data, previousOutputIndex: Int) -> [Input]

    func sentTransaction(byHash: Data) -> SentTransaction?
    func update(sentTransaction: SentTransaction)
    func delete(sentTransaction: SentTransaction)
    func add(sentTransaction: SentTransaction)

    func publicKeys() -> [PublicKey]
    func publicKey(raw: Data) -> PublicKey?
    func publicKey(hashP2pkh: Data) -> PublicKey?
    func publicKey(hashP2wpkhWrappedInP2sh: Data) -> PublicKey?
    func publicKey(convertedForP2tr: Data) -> PublicKey?
    func add(publicKeys: [PublicKey])
    func publicKeysWithUsedState() -> [PublicKeyWithUsedState]
    func publicKey(byPath: String) -> PublicKey?
}

// 交易分页查询时的预过滤类型。SAFE3 reserve 过滤下推到存储层：
// - 若 storage 实现了 `ISafe3FilteredStorage`（如 GrdbStorage），可下推到 SQL 层
// - 若 storage 未实现该协议，DataProvider 在内存里二次过滤
//
// 协议 IStorage 公共签名未变，自定义 IStorage 实现不需要任何修改即可继续工作。
public enum TransactionFilterKind {
    case none                        // 不过滤（默认，行为与原版一致）
    case safe3ReserveOnly            // SAFE3: 只保留所有 output 都是 SAFE3 reserve 的交易
}

/// 存储层 SAFE3 过滤的"可选"协议。
///
/// 实现者可选择实现：GrdbStorage 通过 override 把 safe3ReserveOnly 下推到 SQL 层。
/// 未实现的 IStorage 走 DataProvider 内存里的二次过滤，行为完全等价。
///
/// 独立成单独协议的原因：
/// 1. 不破坏 IStorage 公共签名（外部自定义 IStorage 实现不需要跟着改）
/// 2. Swift dynamic dispatch 需要方法在协议里才能 override，否则会走 extension 的 static
///    dispatch，override 不生效
public protocol ISafe3FilteredStorage: IStorage {
    func fullInfo(forTransactions: [TransactionWithBlock], transactionFilterKind: TransactionFilterKind) -> [FullTransactionForInfo]
    func validOrInvalidTransactionsFullInfo(
        fromTimestamp: Int?, fromOrder: Int?, descending: Bool,
        type: TransactionFilterType?, limit: Int?, transactionFilterKind: TransactionFilterKind
    ) -> [FullTransactionForInfo]
}

public protocol IRestoreKeyConverter {
    func keysForApiRestore(publicKey: PublicKey) -> [String]
    func bloomFilterElements(publicKey: PublicKey) -> [Data]
}

public protocol IPublicKeyManager {
    func usedPublicKeys(change: Bool) -> [PublicKey]
    func changePublicKey() throws -> PublicKey
    func receivePublicKey() throws -> PublicKey
    func fillGap() throws
    func addKeys(keys: [PublicKey])
    func gapShifts() -> Bool
    func publicKey(byPath: String) throws -> PublicKey
}

public protocol IBloomFilterManagerDelegate: AnyObject {
    func bloomFilterUpdated(bloomFilter: BloomFilter)
}

public protocol IBloomFilterManager: AnyObject {
    var delegate: IBloomFilterManagerDelegate? { get set }
    var bloomFilter: BloomFilter? { get }
    func regenerateBloomFilter()
}

public protocol IPeerGroup: AnyObject {
    var publisher: AnyPublisher<PeerGroupEvent, Never> { get }
    var started: Bool { get }

    func start()
    func stop()
    func refresh()
    func reconnectPeers()

    func isReady(peer: IPeer) -> Bool
}

protocol IPeerManager: AnyObject {
    var totalPeersCount: Int { get }
    var connected: [IPeer] { get }
    var sorted: [IPeer] { get }
    var readyPeers: [IPeer] { get }
    func add(peer: IPeer)
    func peerDisconnected(peer: IPeer)
    func disconnectAll()
}

public protocol IPeer: AnyObject {
    var delegate: PeerDelegate? { get set }
    var localBestBlockHeight: Int32 { get set }
    var announcedLastBlockHeight: Int32 { get }
    var subVersion: String { get }
    var host: String { get }
    var logName: String { get }
    var ready: Bool { get }
    var connected: Bool { get }
    var connectionTime: Double { get }
    var tasks: [PeerTask] { get }
    func connect()
    func disconnect(error: Error?)
    func add(task: PeerTask)
    func filterLoad(bloomFilter: BloomFilter)
    func sendMempoolMessage()
    func sendPing(nonce: UInt64)
    func equalTo(_ peer: IPeer?) -> Bool
}

public protocol PeerDelegate: AnyObject {
    func peerReady(_ peer: IPeer)
    func peerBusy(_ peer: IPeer)
    func peerDidConnect(_ peer: IPeer)
    func peerDidDisconnect(_ peer: IPeer, withError error: Error?)

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask)
    func peer(_ peer: IPeer, didReceiveMessage message: IMessage)
}

public protocol IPeerTaskRequester: AnyObject {
    var protocolVersion: Int32 { get }
    func send(message: IMessage)
}

public protocol IPeerTaskDelegate: AnyObject {
    func handle(completedTask task: PeerTask)
    func handle(failedTask task: PeerTask, error: Error)
}

protocol IPeerConnection: AnyObject {
    var delegate: PeerConnectionDelegate? { get set }
    var host: String { get }
    var port: Int { get }
    var logName: String { get }
    func connect()
    func disconnect(error: Error?)
    func send(message: IMessage)
}

protocol IConnectionTimeoutManager: AnyObject {
    func reset()
    func timePeriodPassed(peer: IPeer)
}

public protocol IBlockSyncListener: AnyObject {
    func blocksSyncFinished()
    func currentBestBlockHeightUpdated(height: Int32, maxBlockHeight: Int32)
    func blockForceAdded()
}

public protocol IBlockHashFetcher {
    func fetch(heights: [Int]) async throws -> [Int: String]
}

protocol IPeerAddressManagerDelegate: AnyObject {
    func newIpsAdded()
}

protocol IPeerDiscovery {
    var peerAddressManager: IPeerAddressManager? { get set }
    func lookup(dnsSeeds: [String]) -> Bool
}

protocol IFactory {
    func block(withHeader header: BlockHeader, previousBlock: Block) -> Block
    func block(withHeader header: BlockHeader, height: Int) -> Block
    func blockHash(withHeaderHash headerHash: Data, height: Int, order: Int) -> BlockHash
    func peer(withHost host: String, eventLoopGroup: MultiThreadedEventLoopGroup, logger: Logger?) -> IPeer
    func transaction(version: Int, lockTime: Int) -> Transaction
    func inputToSign(withPreviousOutput: UnspentOutput, script: Data, sequence: Int) -> InputToSign
    func output(withIndex index: Int, address: Address, value: Int, publicKey: PublicKey?) -> Output
    func output(withIndex index: Int, address: Address, value: Int, publicKey: PublicKey?, unlockedHeight: Int?, reserve: Data?) -> Output
    func nullDataOutput(data: Data) -> Output
    func bloomFilter(withElements: [Data]) -> BloomFilter
}

public protocol IApiTransactionProvider {
    func transactions(addresses: [String], stopHeight: Int?) async throws -> [ApiTransactionItem]
}

protocol ISyncManager {
    func start()
    func stop()
}

protocol IApiSyncer {
    var listener: IApiSyncerListener? { get set }
    var willSync: Bool { get }
    func sync()
    func terminate()
    func updateMaxHeight(maxHeight: Int)
}

public protocol IHasher {
    func hash(data: Data) -> Data
}

protocol IApiSyncerListener: AnyObject {
    func onSyncSuccess()
    func transactionsFound(count: Int)
    func onSyncFailed(error: Error)
}

protocol IPaymentAddressParser {
    func parse(paymentAddress: String) -> BitcoinPaymentData
}

public protocol IAddressConverter {
    func convert(address: String) throws -> Address
    func convert(lockingScriptPayload: Data, type: ScriptType) throws -> Address
    func convert(publicKey: PublicKey, type: ScriptType) throws -> Address
}

public protocol IScriptConverter {
    func decode(data: Data) throws -> Script
}

protocol IScriptExtractor: AnyObject {
    var type: ScriptType { get }
    func extract(from data: Data, converter: IScriptConverter) throws -> Data?
}

protocol IOutputsCache: AnyObject {
    func add(outputs: [Output])
    func valueSpent(by input: Input) -> Int?
    func clear()
}

protocol ITransactionInvalidator {
    func invalidate(transaction: Transaction)
}

protocol ITransactionConflictsResolver {
    func transactionsConflicting(withInblockTransaction transaction: FullTransaction) -> [Transaction]
    func transactionsConflicting(withPendingTransaction transaction: FullTransaction) -> [Transaction]
    func incomingPendingTransactionsConflicting(with transaction: FullTransaction) -> [Transaction]
    func isTransactionReplaced(transaction: FullTransaction) -> Bool
}

public protocol IBlockTransactionProcessor: AnyObject {
    var listener: IBlockchainDataListener? { get set }

    func processReceived(transactions: [FullTransaction], inBlock block: Block, skipCheckBloomFilter: Bool) throws
}

public protocol IPendingTransactionProcessor: AnyObject {
    var listener: IBlockchainDataListener? { get set }

    func processReceived(transactions: [FullTransaction], skipCheckBloomFilter: Bool) throws
    func processCreated(transaction: FullTransaction) throws
}

protocol ITransactionExtractor {
    func extract(transaction: FullTransaction)
}

protocol ITransactionLinker {
    func handle(transaction: FullTransaction)
}

public protocol ITransactionSyncer: AnyObject {
    func newTransactions() -> [FullTransaction]
    func handleRelayed(transactions: [FullTransaction])
    func handleInvalid(fullTransaction: FullTransaction)
    func shouldRequestTransaction(hash: Data) -> Bool
}

public protocol ITransactionCreator {
    func create(params: SendParameters) throws -> FullTransaction
    func create(from: UnspentOutput, params: SendParameters) throws -> FullTransaction
    func create(from mutableTransaction: MutableTransaction) throws -> FullTransaction
    func createRawTransaction(params: SendParameters) throws -> Data
}

protocol ITransactionBuilder {
    func buildTransaction(params: SendParameters) throws -> MutableTransaction
    func buildTransaction(from: UnspentOutput, params: SendParameters) throws -> MutableTransaction
}

protocol ITransactionFeeCalculator {
    func sendInfo(params: SendParameters) throws -> BitcoinSendInfo
}

protocol IBlockchain {
    var listener: IBlockchainDataListener? { get set }

    func connect(merkleBlock: MerkleBlock) throws -> Block
    func forceAdd(merkleBlock: MerkleBlock, height: Int) throws -> Block
    func handleFork() throws
    func deleteBlocks(blocks: [Block]) throws
}

public protocol IBlockchainDataListener: AnyObject {
    func onUpdate(updated: [Transaction], inserted: [Transaction], inBlock: Block?)
    func onDelete(transactionHashes: [String])
    func onInsert(block: Block)
}

protocol IInputSigner {
    func sigScriptData(transaction: Transaction, inputsToSign: [InputToSign], outputs: [Output], index: Int) throws -> [Data]
}

public protocol ITransactionSizeCalculator {
    func transactionSize(previousOutputs: [Output], outputScriptTypes: [ScriptType], memo: String?) -> Int
    func transactionSize(previousOutputs: [Output], outputScriptTypes: [ScriptType], memo: String?, pluginDataOutputSize: Int) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func witnessSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
    func transactionSize(previousOutputs: [Output], outputs: [Output]) throws -> Int
}

public protocol IDustCalculator {
    func dust(type: ScriptType) -> Int
}

public protocol IUnspentOutputSelector {
    func allSpendable(filters: UtxoFilters) -> [UnspentOutput]
    func select(params: SendParameters, outputScriptType: ScriptType, changeType: ScriptType, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo
}

public protocol IUnspentOutputProvider {
    func spendableUtxo(filters: UtxoFilters) -> [UnspentOutput]
    func confirmedSpendableUtxo(filters: UtxoFilters) -> [UnspentOutput]
}

public protocol IBalanceProvider {
    var balanceInfo: BalanceInfo { get }
}

// 默认 no-op 实现：保持向后兼容（外部 IBalanceProvider 实现不需要修改即可编译）。
// UnspentOutputProvider 通过覆盖此方法提供真正的缓存失效逻辑。
public extension IBalanceProvider {
    func invalidateCache() {}
}

public protocol IBlockSyncer: AnyObject {
    var localDownloadedBestBlockHeight: Int32 { get }
    var localKnownBestBlockHeight: Int32 { get }
    func prepareForDownload()
    func downloadStarted()
    func downloadIterationCompleted()
    func downloadCompleted()
    func downloadFailed()
    func getBlockHashes(limit: Int) -> [BlockHash]
    func getBlockLocatorHashes(peerLastBlockHeight: Int32) -> [Data]
    func add(blockHashes: [Data])
    func handle(merkleBlock: MerkleBlock, maxBlockHeight: Int32) throws

    func shouldRequestBlock(withHash hash: Data) -> Bool
    func updateCheckpoint(checkpoint: Checkpoint)

}

protocol ISyncManagerDelegate: AnyObject {
    func kitStateUpdated(state: BitcoinCore.KitState)
}

public protocol ITransactionInfo: AnyObject {
    init(uid: String, transactionHash: String, transactionIndex: Int, inputs: [TransactionInputInfo], outputs: [TransactionOutputInfo], amount: Int, type: TransactionType, fee: Int?, blockHeight: Int?, timestamp: Int, status: TransactionStatus, conflictingHash: String?, rbfEnabled: Bool)
}

public protocol ITransactionInfoConverter {
    var baseTransactionInfoConverter: IBaseTransactionInfoConverter! { get set }
    func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo
}

protocol IDataProvider {
    var delegate: IDataProviderDelegate? { get set }

    var lastBlockInfo: BlockInfo? { get }
    var balance: BalanceInfo { get }
    func debugInfo(network: INetwork, scriptType: ScriptType, addressConverter: IAddressConverter) -> String
    func transactions(fromUid: String?, type: TransactionFilterType?, descending: Bool, limit: Int?) -> [TransactionInfo]
    func transaction(hash: String) -> TransactionInfo?
    func transactionInfo(from fullInfo: FullTransactionForInfo) -> TransactionInfo
    func rawTransaction(transactionHash: String) -> String?
    
    func updateLastBlockInfo()
}

protocol IDataProviderDelegate: AnyObject {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: BalanceInfo)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
}

public protocol INetwork: AnyObject {
    var maxBlockSize: UInt32 { get }
    var protocolVersion: Int32 { get }
    var bundleName: String { get }
    var pubKeyHash: UInt8 { get }
    var privateKey: UInt8 { get }
    var scriptHash: UInt8 { get }
    var bech32PrefixPattern: String { get }
    var xPubKey: UInt32 { get }
    var xPrivKey: UInt32 { get }
    var magic: UInt32 { get }
    var port: Int { get }
    var dnsSeeds: [String] { get }
    var dustRelayTxFee: Int { get }
    var bip44Checkpoint: Checkpoint { get }
    var lastCheckpoint: Checkpoint { get }
    var coinType: UInt32 { get }
    var sigHash: SigHashType { get }
    var syncableFromApi: Bool { get }

    
    func isMainNode(ip: String?) -> Bool

    func getMainNodeIp(list: [String]) -> String?
    
    func markedFailed(ip: String?)
    
    func isSafe() -> Bool

    var blockchairChainId: String { get }

}

protocol IMerkleBlockValidator: AnyObject {
    func set(merkleBranch: IMerkleBranch)
    func merkleBlock(from message: MerkleBlockMessage) throws -> MerkleBlock
}

public protocol IMerkleBranch: AnyObject {
    func calculateMerkleRoot(txCount: Int, hashes: [Data], flags: [UInt8]) throws -> (merkleRoot: Data, matchedHashes: [Data])
}

public protocol IMessage {
    var description: String { get }
}

protocol INetworkMessageParser {
    func parse(data: Data) -> NetworkMessage?
}

public protocol IMessageParser {
    var id: String { get }
    func parse(data: Data) -> IMessage
}

protocol IBlockHeaderParser {
    func parse(byteStream: ByteStream) -> BlockHeader
}

protocol INetworkMessageSerializer {
    func serialize(message: IMessage) throws -> Data
}

public protocol IMessageSerializer {
    var id: String { get }
    func serialize(message: IMessage) -> Data?
}

public protocol IInitialDownload: IPeerTaskHandler, IInventoryItemsHandler {
    var listener: IBlockSyncListener? { get set }
    var syncPeer: IPeer? { get }
    var hasSyncedPeer: Bool { get }
    var publisher: AnyPublisher<InitialDownloadEvent, Never> { get }
    var syncedPeers: [IPeer] { get }
    func isSynced(peer: IPeer) -> Bool

    func updateCheckpoint(checkpoint: Checkpoint)
    func stopDownload()

    func subscribeTo(publisher: AnyPublisher<PeerGroupEvent, Never>)

}

public protocol IInventoryItemsHandler: AnyObject {
    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem])
}

public protocol IPeerTaskHandler: AnyObject {
    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool
}

protocol ITransactionSender {
    func verifyCanSend() throws
    func send(pendingTransaction: FullTransaction)
    func transactionsRelayed(transactions: [FullTransaction])
}

protocol ITransactionSendTimerDelegate: AnyObject {
    func timePassed()
}

protocol ITransactionSendTimer {
    var delegate: ITransactionSendTimerDelegate? { get set }
    func startIfNotRunning()
    func stop()
}

protocol IMerkleBlockHandler: AnyObject {
    func handle(merkleBlock: MerkleBlock) throws
}

// protocol ITransactionHandler: AnyObject {
//    func handle(transaction: FullTransaction, transactionHash: TransactionHash) throws
// }

protocol ITransactionListener: AnyObject {
    func onReceive(transaction: FullTransaction)
}

public protocol IWatchedTransactionDelegate {
    func transactionReceived(transaction: FullTransaction, outputIndex: Int)
    func transactionReceived(transaction: FullTransaction, inputIndex: Int)
}

protocol IWatchedTransactionManager {
    func add(transactionFilter: BitcoinCore.TransactionFilter, delegatedTo: IWatchedTransactionDelegate)
}

protocol IBloomFilterProvider: AnyObject {
    var bloomFilterManager: IBloomFilterManager? { set get }
    func filterElements() -> [Data]
}

protocol IIrregularOutputFinder {
    func hasIrregularOutput(outputs: [Output]) -> Bool
}

public protocol IPlugin: IRestoreKeyConverter {
    var id: UInt8 { get }
    var maxSpendLimit: Int? { get }
    func validate(address: Address) throws
    func processOutputs(mutableTransaction: MutableTransaction, pluginData: IPluginData, skipChecks: Bool) throws
    func processTransactionWithNullData(transaction: FullTransaction, nullDataChunks: inout IndexingIterator<[Chunk]>) throws
    func isSpendable(unspentOutput: UnspentOutput) throws -> Bool
    func inputSequenceNumber(output: Output) throws -> Int
    func parsePluginData(from: String, transactionTimestamp: Int) throws -> IPluginOutputData
    func incrementSequence(sequence: Int) -> Int
}

public extension IPlugin {
    func bloomFilterElements(publicKey _: PublicKey) -> [Data] { [] }
}

public protocol IPluginManager {
    func validate(address: Address, pluginData: [UInt8: IPluginData]) throws
    func maxSpendLimit(pluginData: [UInt8: IPluginData]) throws -> Int?
    func add(plugin: IPlugin)
    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [UInt8: IPluginData], skipChecks: Bool) throws
    func processInputs(mutableTransaction: MutableTransaction) throws
    func processTransactionWithNullData(transaction: FullTransaction, nullDataOutput: Output) throws
    func isSpendable(unspentOutput: UnspentOutput) -> Bool
    func parsePluginData(fromPlugin: UInt8, pluginDataString: String, transactionTimestamp: Int) -> IPluginOutputData?
    func incrementedSequence(of: InputWithPreviousOutput) -> Int
}

public protocol IBlockMedianTimeHelper {
    var medianTimePast: Int? { get }
    func medianTimePast(block: Block) -> Int?
}

protocol IRecipientSetter {
    func setRecipient(to mutableTransaction: MutableTransaction, params: SendParameters, skipChecks: Bool) throws
}

protocol IOutputSetter {
    func setOutputs(to mutableTransaction: MutableTransaction, sortType: TransactionDataSortType)
}

protocol IInputSetter {
    @discardableResult func setInputs(to mutableTransaction: MutableTransaction, params: SendParameters) throws -> InputSetter.OutputInfo
    func setInputs(to mutableTransaction: MutableTransaction, fromUnspentOutput unspentOutput: UnspentOutput, params: SendParameters) throws
}

protocol ILockTimeSetter {
    func setLockTime(to mutableTransaction: MutableTransaction)
}

protocol ITransactionSigner {
    func sign(mutableTransaction: MutableTransaction) throws
}

public protocol IPluginData {}

public protocol IPluginOutputData {}

protocol ITransactionDataSorterFactory {
    func sorter(for type: TransactionDataSortType) -> ITransactionDataSorter
}

protocol ITransactionDataSorter {
    func sort(outputs: [Output]) -> [Output]
    func sort(unspentOutputs: [UnspentOutput]) -> [UnspentOutput]
}
