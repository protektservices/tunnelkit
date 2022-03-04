//
//  NetworkExtensionVPN.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 6/15/18.
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
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// `VPN` based on the NetworkExtension framework.
public class NetworkExtensionVPN: VPN {

    /**
     Initializes a provider.
     */
    public init() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(vpnDidUpdate(_:)), name: .NEVPNStatusDidChange, object: nil)
        nc.addObserver(self, selector: #selector(vpnDidReinstall(_:)), name: .NEVPNConfigurationChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: VPN

    public func prepare() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
        }
    }
    
    public func install(
        _ tunnelBundleIdentifier: String,
        configuration: NetworkExtensionConfiguration,
        extra: NetworkExtensionExtra?,
        completionHandler: ((Result<NETunnelProviderManager, Error>) -> Void)?
    ) {
        let proto: NETunnelProviderProtocol
        do {
            proto = try configuration.asTunnelProtocol(
                withBundleIdentifier: tunnelBundleIdentifier,
                extra: extra
            )
        } catch {
            completionHandler?(.failure(error))
            return
        }
        lookupAll { result in
            switch result {
            case .success(let managers):

                // install (new or existing) then callback
                let targetManager = managers.first {
                    $0.isTunnel(withIdentifier: tunnelBundleIdentifier)
                } ?? NETunnelProviderManager()
                    
                self.install(
                    targetManager,
                    title: configuration.title,
                    protocolConfiguration: proto,
                    onDemandRules: extra?.onDemandRules ?? [],
                    completionHandler: completionHandler
                )

                // remove others afterwards (to avoid permission request)
                managers.filter {
                    !$0.isTunnel(withIdentifier: tunnelBundleIdentifier)
                }.forEach {
                    $0.removeFromPreferences(completionHandler: nil)
                }
                
            case .failure(let error):
                completionHandler?(.failure(error))
                self.notifyError(error)
            }
        }
    }
    
    public func reconnect(
        _ tunnelBundleIdentifier: String,
        configuration: NetworkExtensionConfiguration,
        extra: Extra?,
        delay: Double?
    ) {
        let delay = delay ?? 2.0
        install(
            tunnelBundleIdentifier,
            configuration: configuration,
            extra: extra
        ) { result in
            switch result {
            case .success(let manager):
                if manager.connection.status != .disconnected {
                    manager.connection.stopVPNTunnel()
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.connect(manager)
                    }
                } else {
                    self.connect(manager)
                }

            case .failure(let error):
                self.notifyError(error)
            }
        }
    }
    
    public func disconnect() {
        lookupAll {
            if case .success(let managers) = $0 {
                managers.forEach {
                    $0.connection.stopVPNTunnel()
                    $0.isOnDemandEnabled = false
                    $0.isEnabled = false
                    $0.saveToPreferences(completionHandler: nil)
                }
            }
        }
    }
    
    public func uninstall() {
        lookupAll {
            if case .success(let managers) = $0 {
                managers.forEach {
                    $0.connection.stopVPNTunnel()
                    $0.removeFromPreferences(completionHandler: nil)
                }
            }
        }
    }

    // MARK: Helpers
    
    private func install(
        _ manager: NETunnelProviderManager,
        title: String,
        protocolConfiguration: NETunnelProviderProtocol,
        onDemandRules: [NEOnDemandRule],
        completionHandler: ((Result<NETunnelProviderManager, Error>) -> Void)?
    ) {
        manager.localizedDescription = title
        manager.protocolConfiguration = protocolConfiguration

        if !onDemandRules.isEmpty {
            manager.onDemandRules = onDemandRules
            manager.isOnDemandEnabled = true
        } else {
            manager.isOnDemandEnabled = false
        }

        manager.isEnabled = true
        manager.saveToPreferences { error in
            if let error = error {
                manager.isOnDemandEnabled = false
                manager.isEnabled = false
                completionHandler?(.failure(error))
                self.notifyError(error)
                return
            }
            manager.loadFromPreferences { error in
                if let error = error {
                    completionHandler?(.failure(error))
                    self.notifyError(error)
                    return
                }
                completionHandler?(.success(manager))
                self.notifyReinstall(manager)
            }
        }
    }

    private func connect(_ manager: NETunnelProviderManager) {
        do {
            try manager.connection.startVPNTunnel()
        } catch {
            notifyError(error)
        }
    }
    
    public func lookupAll(completionHandler: @escaping (Result<[NETunnelProviderManager], Error>) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            completionHandler(.success(managers ?? []))
        }
    }

    // MARK: Notifications

    @objc private func vpnDidUpdate(_ notification: Notification) {
        guard let connection = notification.object as? NETunnelProviderSession else {
            return
        }
        notifyStatus(connection)
    }

    @objc private func vpnDidReinstall(_ notification: Notification) {
        guard let manager = notification.object as? NETunnelProviderManager else {
            return
        }
        notifyReinstall(manager)
    }
    
    private func notifyReinstall(_ manager: NETunnelProviderManager) {
        let bundleId = manager.tunnelBundleIdentifier
        log.debug("VPN did reinstall (\(bundleId ?? "?")): isEnabled=\(manager.isEnabled)")

        var notification = Notification(name: VPNNotification.didReinstall)
        notification.vpnBundleIdentifier = bundleId
        notification.vpnIsEnabled = manager.isEnabled
        NotificationCenter.default.post(notification)
    }
    
    private func notifyStatus(_ connection: NETunnelProviderSession) {
        guard let _ = connection.manager.localizedDescription else {
            log.verbose("Ignoring VPN notification from bogus manager")
            return
        }
        let bundleId = connection.manager.tunnelBundleIdentifier
        log.debug("VPN status did change (\(bundleId ?? "?")): isEnabled=\(connection.manager.isEnabled), status=\(connection.status.rawValue)")

        var notification = Notification(name: VPNNotification.didChangeStatus)
        notification.vpnBundleIdentifier = bundleId
        notification.vpnIsEnabled = connection.manager.isEnabled
        notification.vpnStatus = connection.status.wrappedStatus
        NotificationCenter.default.post(notification)
    }
    
    private func notifyError(_ error: Error) {
        log.error("VPN command failed: \(error))")

        var notification = Notification(name: VPNNotification.didFail)
        notification.vpnError = error
        NotificationCenter.default.post(notification)
    }
}

private extension NEVPNManager {
    var tunnelBundleIdentifier: String? {
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return proto.providerBundleIdentifier
    }
    
    func isTunnel(withIdentifier bundleIdentifier: String) -> Bool {
        return tunnelBundleIdentifier == bundleIdentifier
    }
}

private extension NEVPNStatus {
    var wrappedStatus: VPNStatus {
        switch self {
        case .connected:
            return .connected
            
        case .connecting, .reasserting:
            return .connecting
            
        case .disconnecting:
            return .disconnecting
            
        case .disconnected, .invalid:
            return .disconnected

        @unknown default:
            return .disconnected
        }
    }
}
