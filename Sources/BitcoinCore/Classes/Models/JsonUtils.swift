import Foundation
import UIKit

public protocol ObjectToString: Codable {}

extension ObjectToString {
    public func toString() -> String {
        let data = try? JSONEncoder().encode(self)
        guard let jsonData = data else { return ""}
        guard let jsonStr = String(data: jsonData, encoding: .utf8) else { return ""}
        return jsonStr
    }
}

extension String {
    public func stringToObj<T>(_ :T.Type) -> T? where T: Codable  {
        guard let data = self.data(using: .utf8) else { return nil}
        let str = try? JSONDecoder().decode(T.self, from: data)
        return str
    }
}

public class LineLock: NSObject, ObjectToString {
    public var lastHeight: Int
    public var lockedValue: String
    public let startMonth: Int
    public let intervalMonth: Int
    public let outputSize: Int
    
    public init(lastHeight: Int, lockedValue: String, startMonth: Int, intervalMonth: Int, outputSize: Int) {
        self.lastHeight = lastHeight
        self.lockedValue = lockedValue
        self.startMonth = startMonth
        self.intervalMonth = intervalMonth
        self.outputSize = outputSize
    }
    
    public func reverseHex() -> String {
        self.toString()
    }
}

