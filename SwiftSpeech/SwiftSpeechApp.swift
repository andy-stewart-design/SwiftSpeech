//
//  SwiftSpeechApp.swift
//  SwiftSpeech
//
//  Created by Andy Stewart on 3/21/26.
//

import SwiftUI

@main
struct SwiftSpeechApp: App {
    var body: some Scene {
        MenuBarExtra("SwiftSpeech", systemImage: "mic") {
            ContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
