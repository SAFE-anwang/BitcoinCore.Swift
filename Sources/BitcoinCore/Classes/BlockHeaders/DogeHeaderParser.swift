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
                // 检查是否有足够的可用字节
                guard byteStream.availableBytes >= offset - headerCount else { return nil }
                byteStream.read(Data.self, count: offset - headerCount)
            }
            return nil
        }
    
        // Parent Block Coinbase Transaction
        /// version
        guard byteStream.availableBytes >= MemoryLayout<Int32>.size else { return nil }
        let _ = Int(byteStream.read(Int32.self))
        
        // 读取 txInCount
        guard byteStream.availableBytes >= 1 else { return nil }
        let txInCount = byteStream.read(VarInt.self)
        for _ in 0 ..< txInCount.underlyingValue {
            /// previousOut
            guard byteStream.availableBytes >= 36 else { return nil }
            let _ = byteStream.read(Data.self, count: 36)
            
            // 读取 scriptSize
            guard byteStream.availableBytes >= 1 else { return nil }
            let scriptSize = Int(byteStream.read(VarInt.self).underlyingValue)
            
            /// scriptData
            guard byteStream.availableBytes >= scriptSize else { return nil }
            let _ = byteStream.read(Data.self, count: scriptSize)
            
            /// sequenceNumber
            guard byteStream.availableBytes >= MemoryLayout<Int32>.size else { return nil }
            let _ = byteStream.read(Int32.self)
        }
        
        // 读取 txOutCount
        guard byteStream.availableBytes >= 1 else { return nil }
        let txOutCount = byteStream.read(VarInt.self)
        for _ in 0 ..< txOutCount.underlyingValue {
            /// amount
            guard byteStream.availableBytes >= MemoryLayout<UInt64>.size else { return nil }
            let _ = byteStream.read(UInt64.self)
            
            // 读取 scriptSize
            guard byteStream.availableBytes >= 1 else { return nil }
            let scriptSize = Int(byteStream.read(VarInt.self).underlyingValue)
            
            /// scriptData
            guard byteStream.availableBytes >= scriptSize else { return nil }
            let _ = byteStream.read(Data.self, count: scriptSize)
        }
        
        /// lockTime
        guard byteStream.availableBytes >= MemoryLayout<UInt32>.size else { return nil }
        let _ = byteStream.read(UInt32.self)
        
        // Coinbase Link
        
        guard byteStream.availableBytes >= 32 else { return nil }
        let parentHeaderHash = byteStream.read(Data.self, count: 32)
        
        /// Number of links in branch
        guard byteStream.availableBytes >= 1 else { return nil }
        let numberOfHashes = byteStream.read(VarInt.self)
        var coinbaseLinkHashes = [Data]()
        for _ in 0 ..< numberOfHashes.underlyingValue {
            guard byteStream.availableBytes >= 32 else { return nil }
            coinbaseLinkHashes.append(byteStream.read(Data.self, count: 32))
        }
        
        /// Branch sides bitmask
        guard byteStream.availableBytes >= MemoryLayout<Int32>.size else { return nil }
        let _ = Int(byteStream.read(Int32.self))
        
        // Aux Blockchain Link
        
        /// Number of links in branch
        guard byteStream.availableBytes >= 1 else { return nil }
        let numberOfLinks = byteStream.read(VarInt.self)
        var auxBlockchainLinkHashes = [Data]()
        for _ in 0 ..< numberOfLinks.underlyingValue {
            guard byteStream.availableBytes >= 32 else { return nil }
            auxBlockchainLinkHashes.append(byteStream.read(Data.self, count: 32))
        }
        
        /// Aux Branch sides bitmask
        guard byteStream.availableBytes >= MemoryLayout<Int32>.size else { return nil }
        let _ = Int(byteStream.read(Int32.self))
        
        // Parent Block Header
        guard byteStream.availableBytes >= 80 else { return nil }
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
