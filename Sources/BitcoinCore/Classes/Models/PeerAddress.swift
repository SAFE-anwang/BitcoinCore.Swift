import GRDB

public class PeerAddress: Record {
    let ip: String
    var score: Int
    var connectionTime: Double?
    var lastBlock: Int32

    public init(ip: String, score: Int, lastBlock: Int32 = 0 ) {
        self.ip = ip
        self.score = score
        self.lastBlock = lastBlock
        
        super.init()
    }

    override open class var databaseTableName: String {
        return "peerAddresses"
    }

    enum Columns: String, ColumnExpression {
        case ip
        case score
        case connectionTime
        case lastBlock
    }

    required init(row: Row) {
        ip = row[Columns.ip]
        score = row[Columns.score]
        connectionTime = row[Columns.connectionTime]
        lastBlock = row[Columns.lastBlock]
        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.ip] = ip
        container[Columns.score] = score
        container[Columns.connectionTime] = connectionTime
        container[Columns.lastBlock] = lastBlock
    }

}
