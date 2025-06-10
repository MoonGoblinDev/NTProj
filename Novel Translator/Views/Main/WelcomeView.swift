//
//  WelcomeView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Welcome to Novel Translator", systemImage: "book.and.globe")
                .font(.largeTitle)
        } description: {
            Text("Create a new project to begin translating your novels with the power of AI.\n\nClick the '+' button in the sidebar to get started.")
                .multilineTextAlignment(.center)
        }
    }
}
