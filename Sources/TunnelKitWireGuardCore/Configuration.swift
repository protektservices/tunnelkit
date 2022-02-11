//
//  Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 11/23/21.
//  Copyright (c) 2022 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import WireGuardKit
import NetworkExtension

extension WireGuard {
    public struct Peer {
        public var publicKey: String
        
        public var preSharedKey: String?

        public var endpoint: String?
        
        public var allowedIPs: [String]?
        
        public var keepAliveInterval: UInt16?

        public init(publicKey: String) {
            self.publicKey = publicKey
        }
    }

    public struct ConfigurationBuilder {
        public var privateKey: String
        
        public var publicKey: String? {
            return PrivateKey(base64Key: privateKey)?.publicKey.base64Key
        }
        
        public var addresses: [String]?
        
        public var dns: [String]?

        public var mtu: UInt16?
        
        public var peers: [Peer]
        
        public init(privateKey: String) {
            self.privateKey = privateKey
            peers = []
        }

        public func build() -> Configuration? {
            guard let clientPrivateKey = PrivateKey(base64Key: privateKey) else {
                return nil
            }

            var interfaceConfiguration = InterfaceConfiguration(privateKey: clientPrivateKey)
            if let clientAddresses = addresses?.mapOptional({ IPAddressRange(from: $0) }) {
                interfaceConfiguration.addresses = clientAddresses
            }
            if let dnsServers = dns?.mapOptional({ DNSServer(from: $0) }) {
                interfaceConfiguration.dns = dnsServers
            }
            interfaceConfiguration.mtu = mtu
            
            var peerConfigurations: [PeerConfiguration] = []
            for peer in peers {
                guard let publicKey = PublicKey(base64Key: peer.publicKey) else {
                    continue
                }
                // XXX: this is actually optional in WireGuard
                guard let endpointString = peer.endpoint, let endpoint = Endpoint(from: endpointString) else {
                      return nil
                }

                var cfg = PeerConfiguration(publicKey: publicKey)
                if let preSharedKey = peer.preSharedKey {
                    cfg.preSharedKey = PreSharedKey(base64Key: preSharedKey)
                }
                if let allowedIPs = peer.allowedIPs?.mapOptional(IPAddressRange.init(from:)) {
                    cfg.allowedIPs = allowedIPs
                }
                cfg.endpoint = endpoint
                cfg.persistentKeepAlive = peer.keepAliveInterval

                peerConfigurations.append(cfg)
            }
            guard !peers.isEmpty else {
                return nil
            }

            let tunnelConfiguration = TunnelConfiguration(name: nil, interface: interfaceConfiguration, peers: peerConfigurations)
            return Configuration(tunnelConfiguration: tunnelConfiguration)
        }
    }

    public struct Configuration: Codable {
        public let tunnelConfiguration: TunnelConfiguration
        
        public init(tunnelConfiguration: TunnelConfiguration) {
            self.tunnelConfiguration = tunnelConfiguration
        }
        
        public func builder() -> WireGuard.ConfigurationBuilder {
            let privateKey = tunnelConfiguration.interface.privateKey.base64Key
            var builder = WireGuard.ConfigurationBuilder(privateKey: privateKey)
            builder.addresses = tunnelConfiguration.interface.addresses.map(\.stringRepresentation)
            builder.dns = tunnelConfiguration.interface.dns.map(\.stringRepresentation)
            builder.mtu = tunnelConfiguration.interface.mtu
            builder.peers = tunnelConfiguration.peers.map {
                var peer = Peer(publicKey: $0.publicKey.base64Key)
                peer.preSharedKey = $0.preSharedKey?.base64Key
                peer.endpoint = $0.endpoint?.stringRepresentation
                peer.allowedIPs = $0.allowedIPs.map(\.stringRepresentation)
                peer.keepAliveInterval = $0.persistentKeepAlive
                return peer
            }
            return builder
        }

        // MARK: Codable
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let wg = try container.decode(String.self)
            let cfg = try TunnelConfiguration(fromWgQuickConfig: wg, called: nil)
            self.init(tunnelConfiguration: cfg)
        }
        
        public func encode(to encoder: Encoder) throws {
            let wg = tunnelConfiguration.asWgQuickConfig()
            var container = encoder.singleValueContainer()
            try container.encode(wg)
        }
    }
}

private extension Array {
    func mapOptional<V>(_ transform: (Self.Element) throws -> V?) rethrows -> [V] {
        return try map(transform)
            .filter { $0 != nil }
            .map { $0! }
    }
}
