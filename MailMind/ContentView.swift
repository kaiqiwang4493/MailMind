import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: MailMindTab = .upload
    @State private var todoListResetID = UUID()
    @State private var historyResetID = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            UploadView()
                .tag(MailMindTab.upload)
                .tabItem {
                    Label("上传", systemImage: "tray.and.arrow.up")
                }

            TodoListView()
                .id(todoListResetID)
                .tag(MailMindTab.todo)
                .tabItem {
                    Label("待办", systemImage: "checklist")
                }

            HistoryView()
                .id(historyResetID)
                .tag(MailMindTab.history)
                .tabItem {
                    Label("历史", systemImage: "clock")
                }
        }
        .tint(MailMindTheme.primary)
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .upload:
                break
            case .todo:
                todoListResetID = UUID()
            case .history:
                historyResetID = UUID()
            }
        }
    }
}

private enum MailMindTab: Hashable {
    case upload
    case todo
    case history
}

#Preview {
    ContentView()
        .modelContainer(for: [MailRecord.self, TodoItem.self], inMemory: true)
}
