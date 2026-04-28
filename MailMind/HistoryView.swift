import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \MailRecord.createdAt, order: .reverse) private var records: [MailRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(records) { record in
                    NavigationLink {
                        MailRecordDetailView(record: record)
                    } label: {
                        HistoryRow(record: record)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MailMindTheme.background.ignoresSafeArea())
            .navigationTitle("历史记录")
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView("还没有历史记录", systemImage: "clock", description: Text("分析过的邮件会保存在这里。"))
                        .foregroundStyle(MailMindTheme.mutedText)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    var record: MailRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CategoryBadge(category: record.category)
                Spacer()
                Text(record.createdAt.mailMindShortDate)
                    .font(.subheadline)
                    .foregroundStyle(MailMindTheme.mutedText)
            }

            Text(record.summary)
                .font(.headline)
                .foregroundStyle(MailMindTheme.text)
                .lineLimit(3)

            Text("\(record.pageCount) 页 · \(record.sourceType.displayName)")
                .font(.subheadline)
                .foregroundStyle(MailMindTheme.mutedText)
        }
        .padding(16)
        .background(MailMindTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 7, x: 0, y: 2)
        .padding(.vertical, 5)
    }
}

private struct MailRecordDetailView: View {
    var record: MailRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionPanel(title: "邮件摘要") {
                    Text(record.summary)
                        .font(.title3)
                        .foregroundStyle(MailMindTheme.text)
                        .lineSpacing(4)
                }

                SectionPanel(title: "邮件类别") {
                    CategoryBadge(category: record.category)
                }

                SectionPanel(title: "生成的待办事项") {
                    if record.suggestedTodos.isEmpty {
                        Text("这封邮件没有生成待办事项。")
                            .font(.body)
                            .foregroundStyle(MailMindTheme.mutedText)
                    } else {
                        ForEach(record.suggestedTodos) { todo in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(todo.title)
                                    .font(.headline)
                                    .foregroundStyle(MailMindTheme.text)
                                Label(todo.deadline.mailMindShortDate, systemImage: "calendar")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MailMindTheme.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(MailMindTheme.background.ignoresSafeArea())
        .navigationTitle("邮件详情")
    }
}
