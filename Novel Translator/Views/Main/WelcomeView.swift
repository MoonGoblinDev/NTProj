import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var isCreatingProject = false
    
    var body: some View {
        ContentUnavailableView {
            Label("Welcome to Novel Translator", systemImage: "book.and.globe")
                .font(.largeTitle)
        } description: {
            Text("Create a new project or open an existing one to begin.")
                .multilineTextAlignment(.center)
                .padding(.bottom)
            
            HStack(spacing: 12) {
                Button("Create New Project...") {
                    isCreatingProject = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Open Project...") {
                    projectManager.openProject()
                }
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            CreateProjectView()
        }
    }
}
