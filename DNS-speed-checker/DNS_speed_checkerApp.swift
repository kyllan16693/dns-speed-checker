//
//  DNS_speed_checkerApp.swift
//  DNS-speed-checker
//
//  Created by Kyllan Wunder on 5/5/24.
//

import SwiftUI

@main
struct DNS_speed_checkerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 360, idealWidth: 380, maxWidth: 460, minHeight: 300, idealHeight: 620, maxHeight: .infinity)
        }
        .windowResizability(.contentSize)
    }
}
