//
//  FMApp.swift
//  入口。
//

import SwiftUI

@main
struct FlyMe2theMoonApp: App {
    var body: some Scene {
        WindowGroup {
            FMRootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
