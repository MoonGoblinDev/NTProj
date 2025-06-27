import SwiftUI

struct GlossaryAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: GlossaryAssistantViewModel
    @State private var isAddChapterPopoverPresented = false
    @State private var isAddCategoryPopoverPresented = false
    
    init(project: TranslationProject, projectManager: ProjectManager, currentChapterID: UUID?) {
        _viewModel = State(initialValue: GlossaryAssistantViewModel(
            project: project,
            projectManager: projectManager,
            currentChapterID: currentChapterID
        ))
    }
    
    // Initializer for SwiftUI Previews
    init(viewModel: GlossaryAssistantViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            switch viewModel.viewState {
            case .initial:
                initialChoiceView
            case .options:
                optionsForm
            case .loading:
                ProgressView(viewModel.mode == .extract ? "Extracting terms..." : "Importing terms...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                resultsView
            case .error:
                errorView
            }
            
            Divider()
            footer
        }
        .frame(minWidth: 800, idealWidth: 900, minHeight: 600)
    }
    
    private var header: some View {
        HStack {
            Text("Glossary Assistant")
                .font(.title2)
            Spacer()
            if viewModel.viewState != .initial {
                Button("Start Over") {
                    viewModel.viewState = .initial
                }
            }
        }
        .padding()
    }
    
    private var initialChoiceView: some View {
        VStack(spacing: 20) {
            Spacer()
            HStack(spacing: 40) {
                ToolCard(
                    title: "Extract from Chapters",
                    description: "Use AI to analyze source and translated text from selected chapters to find new terms.",
                    systemImage: "doc.text.magnifyingglass",
                    action: { viewModel.setModeAndProceed(.extract) }
                )
                
                ToolCard(
                    title: "Import from JSON",
                    description: "Import a pre-formatted JSON file containing an array of glossary entries.",
                    systemImage: "doc.richtext",
                    action: { viewModel.setModeAndProceed(.importJSON) }
                )

                ToolCard(
                    title: "Import from Text",
                    description: "Use AI to parse a plain text file (e.g., 'Term = Translation') into glossary entries.",
                    systemImage: "sparkles",
                    action: { viewModel.setModeAndProceed(.importText) }
                )
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var optionsForm: some View {
        Form {
            Section("Chapters to Analyze") {
                HStack(alignment: .top) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if viewModel.selectedChapters.isEmpty {
                                Text("No chapters selected. Click '+' to add.")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(viewModel.selectedChapters) { chapter in
                                    ChapterTagView(chapter: chapter) {
                                        viewModel.selectedChapterIDs.remove(chapter.id)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Divider()
                    Button { isAddChapterPopoverPresented = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $isAddChapterPopoverPresented, arrowEdge: .bottom) { addChapterPopoverView }
                }
            }
            .padding(.vertical, 4)

            Section("Categories to Extract") {
                HStack(alignment: .top) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if viewModel.selectedCategoryItems.isEmpty {
                                Text("No categories selected. Click '+' to add.").foregroundStyle(.secondary).padding(.vertical, 4)
                            } else {
                                ForEach(viewModel.selectedCategoryItems, id: \.self) { category in
                                    CategoryTagView(category: category) { viewModel.selectedCategories.remove(category) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Divider()
                    Button { isAddCategoryPopoverPresented = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $isAddCategoryPopoverPresented, arrowEdge: .bottom) { addCategoryPopoverView }
                }
            }
            .padding(.vertical, 4)
            
            Section("Advanced Options") {
                Toggle(isOn: $viewModel.fillContext) {
                    Text("Fill Glossary Context")
                    Text("If disabled, the AI will be instructed to leave the context description blank.").font(.caption).foregroundStyle(.secondary)
                }
                .toggleStyle(.switch)
                
                VStack(alignment: .leading) {
                    Text("Additional Instructions (Optional)")
                    TextEditor(text: $viewModel.additionalQuery).frame(height: 60)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    @ViewBuilder
    private var resultsView: some View {
        if viewModel.selectableEntries.isEmpty {
            ContentUnavailableView("No New Terms Found", systemImage: "sparkles.slash", description: Text("The assistant could not identify any new glossary terms to add."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            resultsList
        }
    }
    
    private var resultsList: some View {
        List($viewModel.selectableEntries) { $item in
            HStack(alignment: .top, spacing: 12) {
                VStack{
                    Spacer()
                    Toggle("", isOn: $item.isSelected).labelsHidden().padding(.top, 6)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 15) {
                        Picker("Category", selection: $item.entry.category) {
                            ForEach(GlossaryEntry.GlossaryCategory.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .background(item.entry.category.highlightColor.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 100)
                        
                        // Add custom arrow indicator
                        .background(
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                    .padding(.trailing, 8)
                            }
                        )
                        
                        .onChange(of: item.entry.category) { _, newCategory in
                            if newCategory != .character {
                                item.entry.gender = nil
                            } else if item.entry.gender == nil {
                                item.entry.gender = .unknown
                            }
                        }
                        
                        if item.entry.category == .character {
                            Picker("Gender", selection: Binding(get: { item.entry.gender ?? .unknown }, set: { item.entry.gender = $0 })) {
                                ForEach(GlossaryEntry.Gender.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .background(item.entry.gender?.genderColor.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 100)
                            .background(
                                HStack {
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.primary)
                                        .font(.caption)
                                        .padding(.trailing, 8)
                                }
                            )
                            Spacer()
                        } else {
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .menuIndicator(.hidden)
                    .labelsHidden()
                    
                    HStack {
                        TextField("Original Term", text: $item.entry.originalTerm).fontWeight(.semibold)
                            .textFieldStyle(.roundedBorder)
                        Text("->").foregroundStyle(.secondary)
                        TextField("Translation", text: $item.entry.translation)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("Context Description", text: $item.entry.contextDescription, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                }
                .textFieldStyle(.plain)
            }
            .padding()
        }
        .listStyle(.inset)
    }
    
    private var errorView: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(.red)
            Text("An Error Occurred").font(.title3).fontWeight(.bold)
            Text(viewModel.errorMessage ?? "An unknown error occurred.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("Back to Options") { viewModel.viewState = .initial }.padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var footer: some View {
        HStack {
            if viewModel.viewState == .results {
                let selectedCount = viewModel.selectableEntries.filter(\.isSelected).count
                Text("\(selectedCount) of \(viewModel.selectableEntries.count) items selected").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
            
            switch viewModel.viewState {
            case .options:
                Button("Start Extraction") { viewModel.startExtraction() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedChapterIDs.isEmpty || viewModel.selectedCategories.isEmpty)
            case .results:
                Button("Add Selected to Glossary") {
                    viewModel.saveSelectedEntriesAndProject()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectableEntries.filter(\.isSelected).isEmpty)
            case .initial, .loading, .error:
                EmptyView()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var addChapterPopoverView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Chapters to Analyze").font(.headline).padding()
            Divider()
            
            if viewModel.unselectedChapters.isEmpty {
                Text("All chapters are already selected.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(viewModel.unselectedChapters) { chapter in
                    Button {
                        viewModel.selectedChapterIDs.insert(chapter.id)
                    } label: {
                        HStack {
                            Text("#\(chapter.chapterNumber) - \(chapter.title)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            if chapter.translatedContent == nil || chapter.translatedContent?.isEmpty == true {
                                Text("Not Translated")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 300, idealHeight: 400)
    }
    
    @ViewBuilder
    private var addCategoryPopoverView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Categories to Extract").font(.headline).padding()
            Divider()
            
            if viewModel.unselectedCategoryItems.isEmpty {
                Text("All categories are already selected.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(viewModel.unselectedCategoryItems, id: \.self) { category in
                    Button {
                        viewModel.selectedCategories.insert(category)
                    } label: {
                        Text(category.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 250, idealHeight: 300)
    }
}

// MARK: - Local Subviews

fileprivate struct ToolCard: View {
    let title: String
    let description: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(width: 220, height: 180)
            .background(.background.secondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct ChapterTagView: View {
    let chapter: Chapter
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(chapter.chapterNumber): \(chapter.title)")
                .font(.callout)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .padding(2)
                    .background(.secondary.opacity(0.3), in: Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.15), in: Capsule())
    }
}

fileprivate struct CategoryTagView: View {
    let category: GlossaryEntry.GlossaryCategory
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(category.displayName)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(Color(nsColor: .controlTextColor)) // Ensure text is readable

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .padding(2)
                    .background(.secondary.opacity(0.3), in: Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(category.highlightColor.opacity(0.25), in: Capsule())
    }
}

// MARK: - Previews

#Preview("Initial State") {
    let mocks = PreviewMocks.shared
    return GlossaryAssistantView(
        project: mocks.project,
        projectManager: mocks.projectManager,
        currentChapterID: mocks.chapter1.id
    )
}

#Preview("Options State") {
    let mocks = PreviewMocks.shared
    let vm = GlossaryAssistantViewModel(
        project: mocks.project,
        projectManager: mocks.projectManager,
        currentChapterID: mocks.chapter1.id
    )
    vm.viewState = .options
    return GlossaryAssistantView(viewModel: vm)
}

#Preview("Results State") {
    let mocks = PreviewMocks.shared
    let vm = GlossaryAssistantViewModel(
        project: mocks.project,
        projectManager: mocks.projectManager,
        currentChapterID: mocks.chapter1.id
    )
    vm.viewState = .results
    vm.selectableEntries = [
        .init(entry: .init(originalTerm: "Lady of the Lake", translation: "湖の乙女", category: .character, contextDescription: "Gave Arthur the sword.", gender: .female)),
        .init(entry: .init(originalTerm: "Gold", translation: "金", category: .object, contextDescription: "The dragon sleeps on it."))
    ]
    return GlossaryAssistantView(viewModel: vm)
}

#Preview("Error State") {
    let mocks = PreviewMocks.shared
    let vm = GlossaryAssistantViewModel(
        project: mocks.project,
        projectManager: mocks.projectManager,
        currentChapterID: mocks.chapter1.id
    )
    vm.viewState = .error
    vm.errorMessage = "The API returned an error (Status Code: 401): Invalid API Key."
    return GlossaryAssistantView(viewModel: vm)
}
