//
//  InspectorView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 29/06/25.
//

// FILE: Novel Translator/Views/Main/InspectorView.swift
import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case chapter = "Chapter"
    case chat = "Chat"
    
    var id: Self { self }
    
    var systemImage: String {
        switch self {
        case .chapter: return "doc.text.below.ecg"
        case .chat: return "bubble.right"
        }
    }
}

struct InspectorView: View {
    @EnvironmentObject private var appContext: AppContext
    
    // To pass down to subviews
    @ObservedObject var project: TranslationProject
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $appContext.selectedInspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content based on picker
            switch appContext.selectedInspectorTab {
            case .chapter:
                ChapterInspectorView(
                    project: project,
                    projectManager: projectManager,
                    workspaceViewModel: workspaceViewModel
                )
            case .chat:
                ChatView(
                    project: project,
                    projectManager: projectManager,
                    workspaceViewModel: workspaceViewModel
                )
            }
        }
    }
}
