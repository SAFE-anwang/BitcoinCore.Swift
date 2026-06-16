import Foundation
import HsToolKit

// Internal hook so GrdbStorage can report save failures without changing IStorage.
protocol IPeerAddressSaveStatusStorage {
    func savePeerAddressesCatchingErrors(_ peerAddresses: [PeerAddress]) -> Bool
}

class PeerAddressManager {
    weak var delegate: IPeerAddressManagerDelegate?

    private let storage: IStorage
    private let network: INetwork
    private var peerDiscovery: IPeerDiscovery
    private let state: PeerAddressManagerState
    private let logger: Logger?
    private let queue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-address-manager", qos: .background)
    private var lookupCount = 0

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
        queue.sync {
            let usedIps = state.usedIps
            var peerAddress = network.isSafe() ? storage.leastScoreFastestPeerAddressSafe(excludingIps: usedIps) : storage.leastScoreFastestPeerAddress(excludingIps: usedIps)

            if network.isSafe(), !network.isMainNode(ip: peerAddress?.ip) {
                if let ip = network.getMainNodeIp(list: usedIps) {
                    lookupCount = 0
                    state.add(usedIp: ip)
                    return ip
                }

                peerAddress = storage.leastScoreFastestPeerAddress(excludingIps: usedIps)
            }

            guard let ip = peerAddress?.ip else {
                if lookupCount < 20, peerDiscovery.lookup(dnsSeeds: network.dnsSeeds) {
                    lookupCount += 1
                }

                return nil
            }

            lookupCount = 0
            state.add(usedIp: ip)
            return ip
        }
    }

    var hasFreshIps: Bool {
        queue.sync {
            guard let peerAddress = storage.leastScoreFastestPeerAddress(excludingIps: state.usedIps) else {
                return false
            }

            return peerAddress.connectionTime == nil
        }
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
            do {
                try storage.deletePeerAddress(byIp: ip)
            } catch {
                print("Failed: \(error)")
            }
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
        let didSave = queue.sync { () -> Bool in
            lookupCount = 0

            if let storage = storage as? IPeerAddressSaveStatusStorage {
                return storage.savePeerAddressesCatchingErrors(newAddresses)
            }

            storage.save(peerAddresses: newAddresses)
            return true
        }

        guard didSave else {
            return
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
