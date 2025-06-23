//
//  ChatView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 21/06/25.
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    
    // The project is owned by the ViewModel, but we observe it here for the view's title
    @ObservedObject var project: TranslationProject
    
    init(project: TranslationProject, projectManager: ProjectManager) {
        self.project = project
        _viewModel = State(initialValue: ChatViewModel(projectManager: projectManager, project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        if viewModel.isThinking {
                            MessageView(message: .init(role: .assistant, content: "...", sources: nil))
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) {
                    if let lastMessageID = viewModel.messages.last?.id {
                        proxy.scrollTo(lastMessageID, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            inputArea
        }
        .navigationTitle(project.name)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        //.background(OpaqueVisualEffect().ignoresSafeArea())
    }
    
    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask about the story...", text: $viewModel.currentInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit(viewModel.sendMessage)
                .disabled(viewModel.isThinking)
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isThinking)
        }
        .padding(12)
        .background(.background.secondary)
    }
}

// MARK: - MessageView Subview
fileprivate struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkle")
                .font(.title2)
                .foregroundStyle(message.role == .user ? .secondary : .primary)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text(message.content)
                    .textSelection(.enabled)
                
                if let sources = message.sources, !sources.isEmpty {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Sources: \(sources.joined(separator: ", "))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
