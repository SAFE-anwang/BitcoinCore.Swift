import Foundation

public class MutableTransaction {
    
    var unlockedHeight: Int? = nil // SAFE
    var reverseHex: String? = nil // SAFE
    
    var transaction = Transaction(version: 2, lockTime: 0)
    var inputsToSign = [InputToSign]()
    var outputs = [Output]()

    public var recipientAddress: Address!
    public var recipientValue = 0
    var changeAddress: Address? = nil
    var changeValue = 0

    private(set) var pluginData = [UInt8: Data]()

    var pluginDataOutputSize: Int {
        if let reverseHex = reverseHex, !reverseHex.starts(with: "73616665") { // safe 线性锁仓
            if let lineLock = reverseHex.stringToObj(LineLock.self) {
                return pluginData.count > 0 ? lineLock.outputSize + 1 + pluginData.reduce(into: 0) { $0 += 1 + $1.value.count } : 0
            }
            return 0
        }else {
           return pluginData.count > 0 ? 1 + pluginData.reduce(into: 0) { $0 += 1 + $1.value.count } : 0                // OP_RETURN (PLUGIN_ID PLUGIN_DATA)
        }
    }

    public init(outgoing: Bool = true) {
        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = outgoing
    }

    public func add(pluginData: Data, pluginId: UInt8) {
        self.pluginData[pluginId] = pluginData
    }

    func add(inputToSign: InputToSign) {
        inputsToSign.append(inputToSign)
    }

    public func build() -> FullTransaction {
        FullTransaction(header: transaction, inputs: inputsToSign.map { $0.input }, outputs: outputs)
    }

}
