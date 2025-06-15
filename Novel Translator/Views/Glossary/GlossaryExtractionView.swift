import SwiftUI

struct GlossaryExtractionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: GlossaryExtractionViewModel
    @State private var isAddChapterPopoverPresented = false
    @State private var isAddCategoryPopoverPresented = false
    
    init(project: TranslationProject, projectManager: ProjectManager, currentChapterID: UUID) {
        _viewModel = State(initialValue: GlossaryExtractionViewModel(
            project: project,
            projectManager: projectManager,
            currentChapterID: currentChapterID
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()

            switch viewModel.viewState {
            case .options:
                optionsForm
            case .loading:
                ProgressView("Extracting terms from text...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                if viewModel.selectableEntries.isEmpty {
                    ContentUnavailableView("No New Terms Found", systemImage: "sparkles.slash", description: Text("The AI could not identify any new glossary terms from the provided text."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
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
            Text("Glossary Extraction")
                .font(.title2)
            Spacer()
        }
        .padding()
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
                    
                    Button {
                        isAddChapterPopoverPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $isAddChapterPopoverPresented, arrowEdge: .bottom) {
                        addChapterPopoverView
                    }
                }
            }
            .padding(.vertical, 4)

            Section("Categories to Extract") {
                HStack(alignment: .top) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if viewModel.selectedCategoryItems.isEmpty {
                                Text("No categories selected. Click '+' to add.")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(viewModel.selectedCategoryItems, id: \.self) { category in
                                    CategoryTagView(category: category) {
                                        viewModel.selectedCategories.remove(category)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    Button {
                        isAddCategoryPopoverPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $isAddCategoryPopoverPresented, arrowEdge: .bottom) {
                        addCategoryPopoverView
                    }
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
                    TextEditor(text: $viewModel.additionalQuery)
                        .frame(height: 60)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var resultsList: some View {
        List($viewModel.selectableEntries) { $item in
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $item.isSelected)
                    .labelsHidden()
                    .padding(.top, 6)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow(alignment: .center) {
                        Text("Source Term")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.entry.originalTerm)
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                    }
                    
                    Divider()
                    
                    GridRow(alignment: .center) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Category", selection: $item.entry.category) {
                            ForEach(GlossaryEntry.GlossaryCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    GridRow(alignment: .center) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Translation", text: $item.entry.translation)
                    }
                    
                    GridRow(alignment: .top) {
                        Text("Context")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        TextField("Context Description", text: $item.entry.contextDescription, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
                .textFieldStyle(.plain)
                .pickerStyle(.menu)
            }
            .padding(.vertical, 8)
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, 120)
    }
    
    private var errorView: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("An Error Occurred")
                .font(.title3)
                .fontWeight(.bold)
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Back to Options") {
                viewModel.viewState = .options
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var footer: some View {
        HStack {
            if viewModel.viewState == .results {
                let selectedCount = viewModel.selectableEntries.filter(\.isSelected).count
                Text("\(selectedCount) of \(viewModel.selectableEntries.count) items selected")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            
            switch viewModel.viewState {
            case .options:
                Button("Start Extraction") {
                    viewModel.startExtraction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedChapterIDs.isEmpty || viewModel.selectedCategories.isEmpty)
            case .results:
                Button("Save Selected") {
                    viewModel.saveSelectedEntriesAndProject()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectableEntries.filter(\.isSelected).isEmpty)
            case .loading, .error:
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
