//
//  DemoView.swift
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
import TunnelKitCore
import TunnelKitManager

struct DemoView: View {
    private let vpn = NetworkExtensionVPN()

    private let keychain = Keychain(group: appGroup)

    private let notifier = Notifier()

    @State private var vpnStatus: VPNStatus = .disconnected

    var body: some View {
        TabView {
            OpenVPNView(vpn: vpn, vpnStatus: vpnStatus, keychain: keychain)
                .tabItem {
                    Text("OpenVPN")
                }

            WireGuardView(vpn: vpn, vpnStatus: vpnStatus)
                .tabItem {
                    Text("WireGuard")
                }
        }
        .task {
            notifier.didChange = didChangeStatus
            notifier.registerNotifications()
            await vpn.prepare()
        }
    }
}

private extension DemoView {
    private func didChangeStatus(_ vpnStatus: VPNStatus) {
        self.vpnStatus = vpnStatus
    }
}

extension VPNStatus {
    func actionText(for vpnStatus: VPNStatus) -> String {
        switch vpnStatus {
        case .connected, .connecting:
            return "Disconnect"

        case .disconnected:
            return "Connect"

        case .disconnecting:
            return "Disconnecting"
        }
    }
}

#Preview {
    DemoView()
}
