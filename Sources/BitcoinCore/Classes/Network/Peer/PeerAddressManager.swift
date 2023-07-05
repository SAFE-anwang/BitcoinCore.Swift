import Foundation
import HsToolKit

class PeerAddressManager {
    weak var delegate: IPeerAddressManagerDelegate?

    private let storage: IStorage
    private let network: INetwork
    private var peerDiscovery: IPeerDiscovery
    private let state: PeerAddressManagerState
    private let logger: Logger?
    private let queue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-address-manager", qos: .background)

    init(storage: IStorage, network: INetwork, peerDiscovery: IPeerDiscovery, state: PeerAddressManagerState = PeerAddressManagerState(), logger: Logger? = nil) {
        self.storage = storage
        self.network = network
        self.peerDiscovery = peerDiscovery
        self.state = state
        self.logger = logger
    }

}

extension PeerAddressManager: IPeerAddressManager {

    var ip: String? {
        guard let ip = network.isSafe() ? storage.leastScoreFastestPeerAddressSafe(excludingIps: state.usedIps)?.ip : storage.leastScoreFastestPeerAddress(excludingIps: state.usedIps)?.ip else {
            peerDiscovery.lookup(dnsSeeds: network.dnsSeeds)
            return nil
        }
        
        if network.isSafe(), !network.isMainNode(ip: ip), let _ip = network.getMainNodeIp(list: state.usedIps) {
            queue.sync {
                state.add(usedIp: _ip)
            }
            return _ip
        }else {
            queue.sync {
                state.add(usedIp: ip)
            }
            return ip
        }
    }

    var hasFreshIps: Bool {
        guard let peerAddress = storage.leastScoreFastestPeerAddress(excludingIps: state.usedIps) else {
            return false
        }

        return peerAddress.connectionTime == nil
    }

    func markSuccess(ip: String) {
        queue.sync {
            state.remove(usedIp: ip)
        }
    }


    func markFailed(ip: String) {
        queue.sync {
            network.markedFailed(ip: ip)
            state.remove(usedIp: ip)
            storage.deletePeerAddress(byIp: ip)
        }
    }

    func add(ips: [String]) {
        let newAddresses = ips
                .filter { !storage.peerAddressExist(address: $0) }
                .map { PeerAddress(ip: $0, score: 0) }

        guard !newAddresses.isEmpty else {
            return
        }

        logger?.debug("Adding new addresses: \(newAddresses.count)")
        queue.sync {
            storage.save(peerAddresses: newAddresses)
        }

        delegate?.newIpsAdded()
    }

    func markConnected(peer: IPeer) {
        queue.sync {
            storage.set(connectionTime: peer.connectionTime, toPeerAddress: peer.host)
        }
    }
    
    // safe
    func saveLastBlock(ip: String, lastBlock: Int32) {
        queue.sync {
            storage.saveLastBlock(ip: ip, lastBlock: lastBlock)
        }
    }
}
