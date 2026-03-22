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

    var body: some Scene {
        MenuBarExtra("SwiftSpeech", systemImage: "mic") {
            ContentView(modelManager: modelManager)
                .task {
                    await modelManager.prepare()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
