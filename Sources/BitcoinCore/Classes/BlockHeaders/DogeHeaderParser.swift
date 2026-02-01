import Foundation
import HsExtensions

public class DogeHeaderParser {
    
    public struct DogeHeaderData {
        public let parentHeaderHash: Data
        public let coinbaseLinkHashes: [Data]
        public let auxBlockchainLinkHashes: [Data]
        public let parentBlockHeader: Data
    }
    
    public static func decodeHeader(byteStream: ByteStream) -> DogeHeaderData? {
        
        let payload = byteStream.data
        
        // 检查 Dogecoin 特定的前缀
        guard payload.count > 3, payload[1] == 0x01, payload[2] == 0x62, payload[3] == 0x00 else { return nil }
        
        // 处理异常数据
        if let offset = abnormalData(data: payload), offset > 0 {
            let headerCount = 80
            if offset - headerCount > 0 {
                byteStream.read(Data.self, count: offset - headerCount)
            }
            return nil
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
        var coinbaseLinkHashes = [Data]()
        for _ in 0 ..< numberOfHashes.underlyingValue {
            coinbaseLinkHashes.append(byteStream.read(Data.self, count: 32))
        }
        
        /// Branch sides bitmask
        let _ = Int(byteStream.read(Int32.self))
        
        // Aux Blockchain Link
        
        /// Number of links in branch
        let numberOfLinks = byteStream.read(VarInt.self)
        var auxBlockchainLinkHashes = [Data]()
        for _ in 0 ..< numberOfLinks.underlyingValue {
            auxBlockchainLinkHashes.append(byteStream.read(Data.self, count: 32))
        }
        /// Aux Branch sides bitmask
        let _ = Int(byteStream.read(Int32.self))
        
        // Parent Block Header
        let parentBlockHeader = byteStream.read(Data.self, count: 80)
        
        return DogeHeaderData(
            parentHeaderHash: parentHeaderHash,
            coinbaseLinkHashes: coinbaseLinkHashes,
            auxBlockchainLinkHashes: auxBlockchainLinkHashes,
            parentBlockHeader: parentBlockHeader
        )
    }

    private static func abnormalData(data: Data) -> Int? {
        // 更灵活的异常数据检测
        // 检查数据长度是否足够
        guard data.count > 124 else { return nil }
        
        // 检查特定模式
        let hex = "0344ffffffff000000000000000000000000000000000000000000000000000000000000000001010000000002000000001a"
        let count = 39
        if data[75...124].hs.reversedHex == hex {
            return data.count - count
        }
        return nil
    }
}
