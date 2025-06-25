// FILE: Novel Translator/Views/Chat/ChatView.swift
//
// ChatView.swift
// Novel Translator
//
// Created by Bregas Satria Wicaksono on 21/06/25.
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var isAddChapterPopoverPresented = false
    
    
    @ObservedObject var project: TranslationProject
    
    init(project: TranslationProject, projectManager: ProjectManager, workspaceViewModel: WorkspaceViewModel) {
        self.project = project
        _viewModel = State(initialValue: ChatViewModel(projectManager: projectManager, project: project, workspaceViewModel: workspaceViewModel))
    }
    
    // This initializer is for SwiftUI Previews
    init(project: TranslationProject, viewModel: ChatViewModel) {
        self.project = project
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.chatWindow) {
                ForEach(ChatViewModel.Window.allCases) { window in
                    Text("\(window.symbol) \(window.rawValue)").tag(window)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            
            //Chat Actions
            HStack {
                Spacer()
                
                Button(action: viewModel.archiveCurrentChat) {
                    Image(systemName: "archivebox")
                }
                .buttonStyle(.plain)
                .help("Archive Current Chat")
                .disabled(!viewModel.canArchiveOrReset || viewModel.chatWindow == .archivedChat)
                
                Button(action: viewModel.resetChat) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help("Reset Current Chat")
                .disabled(!viewModel.canArchiveOrReset || viewModel.chatWindow == .archivedChat)
                
                Menu {
                    Button("Clear Chat Archive", role: .destructive, action: viewModel.clearArchive)
                        .disabled(project.archivedChats.isEmpty)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
            .font(.title3)
            .padding(.vertical, 4)
            .padding(.horizontal)
            
            // Content based on picker
            if viewModel.chatWindow == .chat {
                chatInterface
            } else {
                archiveInterface
            }
        }
        .navigationTitle(project.name)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var chatInterface: some View {
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
            
            if viewModel.mode == .focus {
                contextSelectionArea
                    .padding()
            }
            HStack{
                mode
                inputArea
            }
        }
    }
    
    @ViewBuilder
    private var archiveInterface: some View {
        let sortedArchives = project.archivedChats.sorted { $0.lastModified > $1.lastModified }

        if sortedArchives.isEmpty {
            VStack{
                Spacer()
                ContentUnavailableView("No Archived Chats", systemImage: "archivebox", description: Text("Chats you archive will appear here."))
                Spacer()
            }
            
        } else {
            List {
                ForEach(sortedArchives) { conversation in
                    Button(action: {
                        viewModel.loadConversation(conversation)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(conversation.lastModified.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: viewModel.deleteConversation)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var mode: some View {
        Menu {
            ForEach(ChatViewModel.ChatMode.allCases) { mode in
                Button(action: {
                    viewModel.mode = mode
                }) {
                    HStack {
                        Text("\(mode.symbol) \(mode.rawValue)")
                            .foregroundColor(viewModel.mode == mode ? Color.accentColor : Color.primary)
                    }
                    
                }
            }
        }
    label:
        {
            Text(modeSymbol)
                .font(.system(size: 20))
        }
        
        .font(.title)
        .menuStyle(.borderlessButton)
        .frame(width: 35, height: 35)
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 0))
    }
    
    private var modeSymbol: String {
        switch viewModel.mode {
        case .global:
            return "􀆪"
        case .focus:
            return "􀊫"
        }
    }
    
    private var contextSelectionArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button {
                    isAddChapterPopoverPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .background(.green.opacity(0.3), in: Circle())
                .popover(isPresented: $isAddChapterPopoverPresented, arrowEdge: .bottom) {
                    addChapterPopoverView
                }
                if viewModel.selectedFocusChapters.isEmpty {
                    Text("No chapters selected. Click '+' to add context.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.selectedFocusChapters) { chapter in
                        FocusChapterTagView(
                            chapter: chapter,
                            inclusionType: Binding(
                                get: { viewModel.focusContext[chapter.id] ?? .both },
                                set: { viewModel.focusContext[chapter.id] = $0 }
                            ),
                            onRemove: {
                                viewModel.focusContext.removeValue(forKey: chapter.id)
                            }
                        )
                        .frame(maxWidth: 200)
                        .padding(.horizontal, 3)
                    }
                }
            }
        }
        
    }
    
    @ViewBuilder
    private var addChapterPopoverView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Chapters to Context").font(.headline).padding()
            Divider()
            
            if viewModel.unselectedFocusChapters.isEmpty {
                Text("All chapters are already selected.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(viewModel.unselectedFocusChapters) { chapter in
                    Button {
                        viewModel.focusContext[chapter.id] = .both
                    } label: {
                        HStack {
                            Text("#\(chapter.chapterNumber) - \(chapter.title)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 300, idealHeight: 400)
    }
    
    private var inputArea: some View {
        HStack {
            Capsule()
                .fill(.background.quinary)
                .frame(maxWidth: .infinity, maxHeight: 30)
                .overlay{
                    TextField("Ask a question...", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .onSubmit(viewModel.sendMessage)
                        .disabled(viewModel.isThinking)
                        .padding(.horizontal, 8)
                    
                }
            
            
            
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isThinking)
            .padding(.trailing)
        }
        .padding(.vertical)
        
    }
    
}

// MARK: - Local Subviews

fileprivate struct FocusChapterTagView: View {
    let chapter: Chapter
    @Binding var inclusionType: ChatViewModel.ContextInclusion
    let onRemove: () -> Void
    
    
    var body: some View {
        HStack(spacing: 8) {
            
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(chapter.chapterNumber): \(chapter.title)")
                    .font(.callout)
                    .lineLimit(1)
                
                HStack{
                    Picker("Include", selection: $inclusionType) {
                        ForEach(ChatViewModel.ContextInclusion.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .scaleEffect(0.8, anchor: .leading)
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .padding(2)
                            .background(.red.opacity(0.3), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                }
                
                
            }
            
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        
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

// MARK: - Previews
#Preview("Chat - Global Mode") {
    let mocks = PreviewMocks.shared
    ChatView(
        project: mocks.project,
        projectManager: mocks.projectManager,
        workspaceViewModel: mocks.workspaceViewModel
    )
    .frame(width: 450, height: 600)
}

#Preview("Chat - Focus Mode") {
    let mocks = PreviewMocks.shared
    
    
    
    // Encapsulate the VM setup in a closure to satisfy the ViewBuilder.
    let vm: ChatViewModel = {
        let vm = ChatViewModel(
            projectManager: mocks.projectManager,
            project: mocks.project,
            workspaceViewModel: mocks.workspaceViewModel
        )
        vm.mode = .focus
        vm.focusContext[mocks.chapter3.id] = .source
        return vm
    }()
    
    // Inject the configured view model
    ChatView(project: mocks.project, viewModel: vm)
        .frame(width: 450, height: 600)
    
    
}

#Preview("Chat - With Messages") {
    let mocks = PreviewMocks.shared
    
    
    
    // Encapsulate the VM setup in a closure to satisfy the ViewBuilder.
    let vm: ChatViewModel = {
        let vm = ChatViewModel(
            projectManager: mocks.projectManager,
            project: mocks.project,
            workspaceViewModel: mocks.workspaceViewModel
        )
        vm.messages.append(ChatMessage(role: .user, content: "Tell me about Arthur.", sources: nil))
        vm.messages.append(ChatMessage(role: .assistant, content: "Arthur is a brave knight from the Kingdom of Eldoria. He wields the legendary sword, Excalibur.", sources: ["Ch. 1"]))
        return vm
    }()
    
    ChatView(project: mocks.project, viewModel: vm)
        .frame(width: 450, height: 600)
    
}
