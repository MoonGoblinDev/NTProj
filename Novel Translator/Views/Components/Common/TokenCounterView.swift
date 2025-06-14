//
//  TokenCounterView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 15/06/25.

import SwiftUI
import SwiftData

struct TokenCounterView: View {
    let text: String
    let project: TranslationProject
    let autoCount: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TokenCounterViewModel
    
    @State private var isHovering = false

    init(text: String, project: TranslationProject, autoCount: Bool) {
        self.text = text
        self.project = project
        self.autoCount = autoCount
        _viewModel = State(initialValue: TokenCounterViewModel(project: project, modelContext: .init(try! ModelContainer(for: TranslationProject.self)), autoCount: autoCount))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if viewModel.isRealCount {
                realCountView
            } else {
                estimatedCountView
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .onAppear {
            self.viewModel = TokenCounterViewModel(project: project, modelContext: modelContext, autoCount: autoCount)
            viewModel.updateText(text)
        }
        .onChange(of: text) { _, newText in
            viewModel.updateText(newText)
        }
        .onChange(of: project.selectedModel) { _, _ in
            // Re-fetch if the model changes
            viewModel.retry()
        }
    }
    
    @ViewBuilder
    private var realCountView: some View {
        HStack(spacing: 4) {
            if let provider = project.selectedProvider {
                Image(systemName: provider.logoName)
                    .foregroundColor(provider.logoColor)
            }
            Text("\(viewModel.tokenCount) tokens")
        }
    }
    
    @ViewBuilder
    private var estimatedCountView: some View {
        HStack(spacing: 4) {
            if isHovering {
                Button(action: viewModel.retry) {
                    Label("Get real token count", systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.plain)
                .help("Get real token count from \(project.selectedProvider?.displayName ?? "provider")")
            }
            else{
                Text("~ \(viewModel.tokenCount) tokens")
            }
            
            
        }
        .onHover { hovering in
            withAnimation(.easeInOut) {
                self.isHovering = hovering
            }
        }
        .help(viewModel.errorMessage ?? "An estimated token count based on word count.")
        .foregroundColor(viewModel.errorMessage != nil ? .red : .secondary)
    }
}
