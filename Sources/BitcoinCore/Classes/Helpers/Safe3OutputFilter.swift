import Foundation
import HsExtensions

enum Safe3OutputFilter {
    static let plainSafeReserve = "73616665".hs.hexData!
    static let coinbaseReserve = "7361666573706f730100c2f824c4364195b71a1fcfa0a28ebae20f3501b21b08ae6d6ae8a3bca98ad9d64136e299eba2400183cd0a479e6350ffaec71bcaf0714a024d14183c1407805d75879ea2bf6b691214c372ae21939b96a695c746a6".hs.hexData!
    static let memoReservePrefix = "736166650100c9dcee22bb18bd289bca86e2c8bbb6487089adc9a13d875e538dd35c70a6bea42c0100000a02010012".hs.hexData!
    static let memoReservePrefixLength = memoReservePrefix.count   // 49 bytes

    // 供 SQL subquery 使用的 hex 形式（X'...' 语法）。与上面的 Data 等价。
    static let plainSafeReserveHex = "73616665"
    static let coinbaseReserveHex = "7361666573706f730100c2f824c4364195b71a1fcfa0a28ebae20f3501b21b08ae6d6ae8a3bca98ad9d64136e299eba2400183cd0a479e6350ffaec71bcaf0714a024d14183c1407805d75879ea2bf6b691214c372ae21939b96a695c746a6"
    static let memoReservePrefixHex = "736166650100c9dcee22bb18bd289bca86e2c8bbb6487089adc9a13d875e538dd35c70a6bea42c0100000a02010012"

    static func hasOnlySupportedReserves(in transaction: FullTransactionForInfo) -> Bool {
        for output in transaction.outputs {
            if !isSafe3Reserve(output.reserve) {
                return false
            }
        }

        return true
    }

    static func isSafe3Reserve(_ reserve: Data?) -> Bool {
        guard let reserve else {
            return true
        }

        return reserve == plainSafeReserve || reserve == coinbaseReserve || reserve.starts(with: memoReservePrefix)
    }
}
