//
//  SwiftSpeechApp.swift
//  SwiftSpeech
//
//  Created by Andy Stewart on 3/21/26.
//

import SwiftUI

@main
struct SwiftSpeechApp: App {
    @State private var modelManager = ModelManager()
    @State private var permissionManager = PermissionManager()

    var body: some Scene {
        MenuBarExtra("SwiftSpeech", systemImage: "mic") {
            ContentView(modelManager: modelManager, permissionManager: permissionManager)
                .task {
                    await modelManager.prepare()
                    permissionManager.checkAccessibility()
                    await permissionManager.requestMicrophone()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
