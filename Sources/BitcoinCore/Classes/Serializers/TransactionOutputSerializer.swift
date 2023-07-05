import Foundation
import HsExtensions

class TransactionOutputSerializer {

     static func serialize(output: Output) -> Data {
        var data = Data()

        data += output.value
        let scriptLength = VarInt(output.lockingScript.count)
        data += scriptLength.serialized()
        data += output.lockingScript
         
         // SAFE
         if let unlockedHeight = output.unlockedHeight {
             data += unlockedHeight
         }
         
         if let reverse = output.reserve {
             let count = VarInt(reverse.count)
             data += count.serialized()
             data += reverse
         }

        return data
    }

    static func deserialize(byteStream: ByteStream) -> Output {
        
        let value = Int(byteStream.read(Int64.self))
        let scriptLength: VarInt = byteStream.read(VarInt.self)
        let lockingScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))
        
        return Output(withValue: value, index: 0, lockingScript: lockingScript)
    }
    
    // SAFE
    static func deserializeSafe(byteStream: ByteStream, vout: Int, txVersion: Int) -> Output {
        
        let value = Int(byteStream.read(Int64.self))
        let scriptLength: VarInt = byteStream.read(VarInt.self)
        let lockingScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))
        
        if txVersion >= 102 {
           let unlockedHeight = Int(byteStream.read(Int64.self))
           let count: VarInt = byteStream.read(VarInt.self)
           let reverse = byteStream.read(Data.self, count: Int(count.underlyingValue))
           return Output(withValue: value, index: vout, lockingScript: lockingScript, unlockedHeight: unlockedHeight, reserve: reverse)
        }
        return Output(withValue: value, index: vout, lockingScript: lockingScript)
    }
}
