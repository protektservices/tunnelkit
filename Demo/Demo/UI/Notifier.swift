//
//  Notifier.swift
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

import Foundation
import TunnelKitManager

final class Notifier {
    var didChange: ((VPNStatus) -> Void)?

    private var didRegister = false

    init() {
        //
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func registerNotifications() {
        guard !didRegister else {
            return
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(VPNStatusDidChange(notification:)),
            name: VPNNotification.didChangeStatus,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(VPNDidFail(notification:)),
            name: VPNNotification.didFail,
            object: nil
        )
        didRegister = true
    }

    @objc private func VPNStatusDidChange(notification: Notification) {
        let vpnStatus = notification.vpnStatus
        print("VPNStatusDidChange: \(vpnStatus)")
        didChange?(vpnStatus)
    }

    @objc private func VPNDidFail(notification: Notification) {
        print("VPNStatusDidFail: \(notification.vpnError.localizedDescription)")
    }
}
