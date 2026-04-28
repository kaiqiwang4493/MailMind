import SwiftData
import SwiftUI

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.deadline) private var todos: [TodoItem]
    @State private var selectedSegment: TodoSegment = .pending
    @State private var todoPendingCompletion: TodoItem?
    @State private var isConfirmingSwipeCompletion = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("待办状态", selection: $selectedSegment) {
                    ForEach(TodoSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                List {
                    ForEach(displayedTodos) { todo in
                        NavigationLink {
                            TodoDetailView(todo: todo)
                        } label: {
                            TodoRow(todo: todo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(todo)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            if !todo.isCompleted {
                                Button {
                                    todoPendingCompletion = todo
                                    isConfirmingSwipeCompletion = true
                                } label: {
                                    Label("完成", systemImage: "checkmark")
                                }
                                .tint(MailMindTheme.primary)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if displayedTodos.isEmpty {
                        ContentUnavailableView(
                            selectedSegment == .pending ? "没有待完成事项" : "没有已完成事项",
                            systemImage: selectedSegment == .pending ? "checkmark.circle" : "tray",
                            description: Text(selectedSegment == .pending ? "需要处理的邮件事项会显示在这里。" : "完成后的事项会保存在这里。")
                        )
                        .foregroundStyle(MailMindTheme.mutedText)
                    }
                }
            }
            .background(MailMindTheme.background.ignoresSafeArea())
            .navigationTitle("待办事项")
            .alert("确认完成？", isPresented: $isConfirmingSwipeCompletion) {
                Button("取消", role: .cancel) {
                    todoPendingCompletion = nil
                }
                Button("确认完成") {
                    completePendingTodo()
                }
            } message: {
                Text("完成后，这个事项会移动到已完成列表。")
            }
        }
    }

    private var displayedTodos: [TodoItem] {
        switch selectedSegment {
        case .pending:
            todos.pendingSortedByDeadline
        case .completed:
            todos.filter(\.isCompleted).sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        }
    }

    private func delete(_ todo: TodoItem) {
        modelContext.delete(todo)
        try? modelContext.save()
    }

    private func completePendingTodo() {
        todoPendingCompletion?.markCompleted()
        try? modelContext.save()
        todoPendingCompletion = nil
    }
}

private enum TodoSegment: String, CaseIterable, Identifiable {
    case pending
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "待完成"
        case .completed: "已完成"
        }
    }
}

private struct TodoRow: View {
    var todo: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todo.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MailMindTheme.text)
                        .lineLimit(3)
                    Label(todo.deadline.mailMindShortDate, systemImage: "calendar")
                        .font(.headline)
                        .foregroundStyle(todo.isCompleted ? MailMindTheme.mutedText : deadlineColor)
                }
                Spacer()
                if let category = todo.mailRecord?.category {
                    CategoryBadge(category: category)
                        .font(.caption)
                }
            }
        }
        .padding(16)
        .background(MailMindTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 7, x: 0, y: 2)
        .padding(.vertical, 5)
    }

    private var deadlineColor: Color {
        todo.deadline.timeIntervalSinceNow < 60 * 60 * 24 * 3 ? MailMindTheme.urgent : MailMindTheme.primary
    }
}

private struct TodoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: TodoItem
    @State private var isEditing = false
    @State private var isConfirmingCompletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionPanel(title: "待办事项") {
                    Text(todo.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(MailMindTheme.text)
                }

                SectionPanel(title: "截止日期") {
                    Label(todo.deadline.mailMindShortDate, systemImage: "calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MailMindTheme.primary)
                }

                SectionPanel(title: "邮件内容") {
                    Text(todo.mailSummary)
                        .font(.title3)
                        .foregroundStyle(MailMindTheme.text)
                        .lineSpacing(4)
                }

                if !todo.isCompleted {
                    HStack(spacing: 12) {
                        Button {
                            isEditing = true
                        } label: {
                            Label("编辑", systemImage: "pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(MailMindTheme.primary)

                        Button {
                            isConfirmingCompletion = true
                        } label: {
                            Label("完成", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MailMindTheme.primary)
                        .accessibilityIdentifier("completeTodoButton")
                    }
                }
            }
            .padding(20)
        }
        .background(MailMindTheme.background.ignoresSafeArea())
        .navigationTitle(todo.isCompleted ? "已完成" : "待办详情")
        .sheet(isPresented: $isEditing) {
            EditTodoView(todo: todo)
        }
        .alert("确认完成？", isPresented: $isConfirmingCompletion) {
            Button("取消", role: .cancel) {}
            Button("确认完成") {
                todo.markCompleted()
                try? modelContext.save()
            }
        } message: {
            Text("完成后，这个事项会移动到已完成列表。")
        }
    }
}

private struct EditTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var todo: TodoItem

    var body: some View {
        NavigationStack {
            Form {
                Section("Todo Item") {
                    TextField("需要做什么", text: $todo.title, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Deadline") {
                    DatePicker("截止日期", selection: $todo.deadline, displayedComponents: .date)
                }
            }
            .navigationTitle("编辑待办")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
