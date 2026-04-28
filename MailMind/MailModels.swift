import Foundation
import SwiftData

enum MailCategory: String, CaseIterable, Codable {
    case bill
    case government
    case banking
    case insurance
    case healthcare
    case tax
    case legal
    case school
    case advertisement
    case personal
    case other

    var displayName: String {
        switch self {
        case .bill: "账单"
        case .government: "政府邮件"
        case .banking: "银行"
        case .insurance: "保险"
        case .healthcare: "医疗"
        case .tax: "税务"
        case .legal: "法律"
        case .school: "学校"
        case .advertisement: "广告"
        case .personal: "个人信件"
        case .other: "其他"
        }
    }
}

enum MailSourceType: String, Codable {
    case photos
    case pdf
    case sample

    var displayName: String {
        switch self {
        case .photos: "照片"
        case .pdf: "PDF"
        case .sample: "示例邮件"
        }
    }
}

@Model
final class MailRecord {
    var sourceTypeRawValue: String
    var sourceNames: [String]
    var pageCount: Int
    var extractedText: String
    var summary: String
    var categoryRawValue: String
    var suggestedTodoTitles: [String]
    var suggestedTodoDeadlines: [Date]
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TodoItem.mailRecord)
    var todoItems: [TodoItem]

    init(
        sourceType: MailSourceType,
        sourceNames: [String],
        pageCount: Int,
        extractedText: String,
        summary: String,
        category: MailCategory,
        suggestedTodos: [TodoDraft] = [],
        createdAt: Date = .now,
        todoItems: [TodoItem] = []
    ) {
        self.sourceTypeRawValue = sourceType.rawValue
        self.sourceNames = sourceNames
        self.pageCount = pageCount
        self.extractedText = extractedText
        self.summary = summary
        self.categoryRawValue = category.rawValue
        self.suggestedTodoTitles = suggestedTodos.map(\.title)
        self.suggestedTodoDeadlines = suggestedTodos.map(\.deadline)
        self.createdAt = createdAt
        self.todoItems = todoItems
    }

    var sourceType: MailSourceType {
        MailSourceType(rawValue: sourceTypeRawValue) ?? .sample
    }

    var category: MailCategory {
        MailCategory(rawValue: categoryRawValue) ?? .other
    }

    var suggestedTodos: [SuggestedTodo] {
        suggestedTodoTitles.enumerated().map { index, title in
            SuggestedTodo(
                id: index,
                title: title,
                deadline: index < suggestedTodoDeadlines.count ? suggestedTodoDeadlines[index] : createdAt
            )
        }
    }
}

struct SuggestedTodo: Identifiable, Equatable {
    var id: Int
    var title: String
    var deadline: Date
}

@Model
final class TodoItem {
    var title: String
    var deadline: Date
    var mailSummary: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var mailRecord: MailRecord?

    init(
        title: String,
        deadline: Date,
        mailSummary: String,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        mailRecord: MailRecord? = nil
    ) {
        self.title = title
        self.deadline = deadline
        self.mailSummary = mailSummary
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.mailRecord = mailRecord
    }

    func markCompleted(at date: Date = .now) {
        isCompleted = true
        completedAt = date
    }
}

extension Sequence where Element == TodoItem {
    var pendingSortedByDeadline: [TodoItem] {
        filter { !$0.isCompleted }.sorted { lhs, rhs in
            if lhs.deadline == rhs.deadline {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.deadline < rhs.deadline
        }
    }
}
