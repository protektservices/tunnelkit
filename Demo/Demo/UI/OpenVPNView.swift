//
//  OpenVPNView.swift
//  Demo
//
//  Created by Davide De Rosa on 12/16/23.
//  Copyright (c) 2024 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
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

import SwiftUI
import TunnelKitOpenVPN
import TunnelKitManager

struct OpenVPNView: View {
    let vpn: NetworkExtensionVPN

    let vpnStatus: VPNStatus

    let keychain: Keychain

    @State private var server = "nl-free-50"

    @State private var domain = "protonvpn.net"

    @State private var portText = "80"

    @State private var username = ""

    @State private var password = ""

    var body: some View {
        List {
            formView
            buttonView
        }
    }
}

private extension OpenVPNView {
    var formView: some View {
        Section {
            TextField("Server", text: $server)
            TextField("Domain", text: $domain)
            TextField("Port", text: $portText)
            TextField("Username", text: $username)
            TextField("Password", text: $password)
        }
    }

    var buttonView: some View {
        Section {
            Button(vpnStatus.actionText(for: vpnStatus)) {
                switch vpnStatus {
                case .disconnected:
                    connect()

                case .connected, .connecting, .disconnecting:
                    disconnect()
                }
            }
        }
    }

    func connect() {
        let hostname = ((domain == "") ? server : [server, domain].joined(separator: "."))
        let port = UInt16(portText)!

        let credentials = OpenVPN.Credentials(username, password)
        var builder = OpenVPN.DemoConfiguration.make(params: .init(
            title: "TunnelKit.OpenVPN",
            appGroup: appGroup,
            hostname: hostname,
            port: port,
            socketType: .udp
        ))
        builder.username = credentials.username

        let passwordReference: Data
        do {
            passwordReference = try keychain.set(password: credentials.password, for: credentials.username, context: TunnelIdentifier.openVPN)
        } catch {
            print("Keychain failure: \(error)")
            return
        }

        let cfg = builder
        Task {
            var extra = NetworkExtensionExtra()
            extra.passwordReference = passwordReference
            try await vpn.reconnect(
                TunnelIdentifier.openVPN,
                configuration: cfg,
                extra: extra,
                after: .seconds(2)
            )
        }
    }

    func disconnect() {
        Task {
            await vpn.disconnect()
        }
    }
}

#Preview {
    OpenVPNView(vpn: NetworkExtensionVPN(),
                vpnStatus: .disconnected,
                keychain: Keychain(group: appGroup))
}
