//
//  VPN.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/6/18.
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

/// Helps controlling a VPN without messing with underlying implementations.
public protocol VPN {
    associatedtype Manager
    
    associatedtype Configuration
    
    associatedtype Extra
    
    /**
     Synchronizes with the current VPN state.
     */
    func prepare()
    
    /**
     Installs the VPN profile.

     - Parameter tunnelBundleIdentifier: The bundle identifier of the tunnel extension.
     - Parameter configuration: The configuration to install.
     - Parameter extra: Optional extra arguments.
     - Parameter completionHandler: The completion handler.
     */
    func install(
        _ tunnelBundleIdentifier: String,
        configuration: Configuration,
        extra: Extra?,
        completionHandler: ((Result<Manager, Error>) -> Void)?
    )

    /**
     Reconnects to the VPN.

     - Parameter tunnelBundleIdentifier: The bundle identifier of the tunnel extension.
     - Parameter configuration: The configuration to install.
     - Parameter extra: Optional extra arguments.
     - Parameter delay: The reconnection delay in seconds.
     */
    func reconnect(
        _ tunnelBundleIdentifier: String,
        configuration: Configuration,
        extra: Extra?,
        delay: Double?
    )
    
    /**
     Disconnects from the VPN.
     */
    func disconnect()
    
    /**
     Uninstalls the VPN profile.
     */
    func uninstall()
}
