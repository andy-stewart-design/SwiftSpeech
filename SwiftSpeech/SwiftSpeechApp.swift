//
//  SwiftSpeechApp.swift
//  SwiftSpeech
//
//  Created by Andy Stewart on 3/21/26.
//

import SwiftUI

@main
struct SwiftSpeechApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("SwiftSpeech", systemImage: coordinator.hotkeyManager.isRecording ? "mic.fill" : "mic") {
            ContentView(coordinator: coordinator)
                .onChange(of: coordinator.permissionManager.allGranted) { _, granted in
                    if granted { coordinator.startHotkey() }
                }
        }
        .menuBarExtraStyle(.window)
    }
}
