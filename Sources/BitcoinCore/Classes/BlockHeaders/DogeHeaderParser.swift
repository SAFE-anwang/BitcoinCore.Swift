import Foundation
import HsExtensions

public class DogeHeaderParser {
    
    static func decodeHeader(byteStream: ByteStream) {
        
        let payload = byteStream.data
        
        guard payload[1] == 0x01, payload[2] == 0x62, payload[3] == 0x00 else { return }
        
        if let offset = abnormalData(data: payload), offset > 0 {
            let headerCount = 80
            let _ = byteStream.read(Data.self, count: offset - headerCount)
            return
        }
    
        // Parent Block Coinbase Transaction
        /// version
        let _ = Int(byteStream.read(Int32.self))
        let txInCount = byteStream.read(VarInt.self)
        for _ in 0 ..< txInCount.underlyingValue {
            /// previousOut
            let _ = byteStream.read(Data.self, count: 36)
            let scriptSize = Int(byteStream.read(VarInt.self).underlyingValue)
            /// scriptData
            let _ = byteStream.read(Data.self, count: scriptSize)
            /// sequenceNumber
            let _ = byteStream.read(Int32.self)
        }
        
        let txOutCount = byteStream.read(VarInt.self)
        for _ in 0 ..< txOutCount.underlyingValue {
            /// amount
            let _ = byteStream.read(UInt64.self)
            let scriptSize = Int(byteStream.read(VarInt.self).underlyingValue)
            /// scriptData
            let _ = byteStream.read(Data.self, count: scriptSize)
        }
        /// lockTime
        let _ = byteStream.read(UInt32.self)
        
        
        // Coinbase Link
        
        let parentHeaderHash = byteStream.read(Data.self, count: 32)
        ///  Number of links in branch
        let numberOfHashes = byteStream.read(VarInt.self)
        var hashes = [Data]()
        for _ in 0 ..< numberOfHashes.underlyingValue {
            hashes.append(byteStream.read(Data.self, count: 32))
        }
        
        /// Branch sides bitmask
        let _ = Int(byteStream.read(Int32.self))
        
        // Aux Blockchain Link
        
        /// Number of links in branch
        let numberOfLinks = byteStream.read(VarInt.self)
        var links = [Data]()
        for _ in 0 ..< numberOfLinks.underlyingValue {
            links.append(byteStream.read(Data.self, count: 32))
        }
        /// Aux Branch sides bitmask
        let _ = Int(byteStream.read(Int32.self))
        
        // Parent Block Header
        let _ = byteStream.read(Data.self, count: 80)
        
    }

    private static func abnormalData(data: Data) -> Int? {
        let hex = "0344ffffffff000000000000000000000000000000000000000000000000000000000000000001010000000002000000001a"
        let count = 39
        if data[75...124].hs.reversedHex == hex {
            return data.count - count
        }
        return nil
    }
}
