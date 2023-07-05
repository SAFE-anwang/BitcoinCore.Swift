import Foundation

class OutputSetter {
    private let outputSorterFactory: ITransactionDataSorterFactory
    private let factory: IFactory

    init(outputSorterFactory: ITransactionDataSorterFactory, factory: IFactory) {
        self.outputSorterFactory = outputSorterFactory
        self.factory = factory
    }

}

extension OutputSetter: IOutputSetter {

    func setOutputs(to transaction: MutableTransaction, sortType: TransactionDataSortType) {
        var outputs = [Output]()
        
        let reverseHex = transaction.reverseHex
        var lineLock: LineLock? = nil
        if let address = transaction.recipientAddress {
            if let reverseHex = reverseHex, !reverseHex.starts(with: "73616665") {
                if let _lineLock = reverseHex.stringToObj(LineLock.self) {
                    lineLock = _lineLock
                    let size = _lineLock.outputSize - 1
                    for index in 0 ..< size {
                        let step = 86400 * (_lineLock.startMonth + _lineLock.intervalMonth * index)
                        let unlockedHeight = _lineLock.lastHeight + step
                        outputs.append(factory.output(withIndex: 0, address: address, value: transaction.recipientValue, publicKey: nil, unlockedHeight: unlockedHeight, reserve: "73616665".hs.hexData))
                    }
                }

            }else {
                outputs.append(factory.output(withIndex: 0, address: address, value: transaction.recipientValue, publicKey: nil))
            }
        }

        if let address = transaction.changeAddress {
            outputs.append(factory.output(withIndex: 0, address: address, value: transaction.changeValue, publicKey: nil))
        }

        if !transaction.pluginData.isEmpty {
            var data = Data([OpCode.op_return])

            transaction.pluginData.forEach { key, value in
                data += Data([key]) + value
            }

            outputs.append(factory.nullDataOutput(data: data))
        }

        let sorted = outputSorterFactory.sorter(for: sortType).sort(outputs: outputs)
        sorted.enumerated().forEach { index, transactionOutput in
            transactionOutput.index = index
        }
        
        /**
         * UPDATE FOR SAFE - UNLOCKED_HEIGHT TRANSACTION OUTPUT
         */
        if let unlockedHeight = transaction.unlockedHeight, let toAddress = transaction.recipientAddress {
            transaction.transaction.version = 103
            sorted.forEach { transactionOutput in
                if let _ = lineLock {
                    if transactionOutput.address != toAddress.stringValue {
                        // 线性锁仓找零地址不锁高度
                        transactionOutput.unlockedHeight = 0
                        // 线性锁仓找零地址默认SAFE
                        transactionOutput.reserve = "73616665".hs.hexData
                    }
                }else {
                    transactionOutput.unlockedHeight = transactionOutput.address == toAddress.stringValue ? unlockedHeight : 0
                    
                    if transactionOutput.address == toAddress.stringValue, let reverseHex = reverseHex {
                        transactionOutput.reserve = reverseHex.hs.hexData
                    }else {
                        transactionOutput.reserve = "73616665".hs.hexData
                    }
                }
            }
        }

        transaction.outputs = sorted
    }

}
