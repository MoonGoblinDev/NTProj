//
//  ProjectStatsView.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 10/06/25.
//

import SwiftUI
import SwiftData

struct ProjectStatsView: View {
    let project: TranslationProject
    
    @Query private var stats: [TranslationStats]
    
    // We use an init to filter the @Query based on the incoming project's ID.
    init(project: TranslationProject) {
        self.project = project
        let pId = project.id
        self._stats = Query(filter: #Predicate<TranslationStats> { $0.projectId == pId })
    }
    
    var body: some View {
        VStack {
            if let currentStats = stats.first {
                Form {
                    Section("Progress") {
                        LabeledContent("Completed Chapters", value: "\(currentStats.completedChapters) / \(currentStats.totalChapters)")
                        LabeledContent("Translated Words", value: "\(currentStats.translatedWords) / \(currentStats.totalWords)")
                        ProgressView(value: Double(currentStats.completedChapters), total: Double(max(1, currentStats.totalChapters)))
                    }
                    
                    Section("Cost & Usage") {
                        LabeledContent("Total Tokens Used", value: currentStats.totalTokensUsed.formatted())
                        LabeledContent("Estimated Cost", value: currentStats.estimatedCost, format: .currency(code: "USD"))
                    }
                    
                    Section("Performance") {
                        LabeledContent("Average Translation Time / Chapter", value: "\(String(format: "%.2f", currentStats.averageTranslationTime))s")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .padding()
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Statistics",
                    systemImage: "chart.bar",
                    description: Text("Statistics will appear here as you translate chapters.")
                )
                Spacer()
            }
        }
        .navigationTitle("Statistics")
    }
}
