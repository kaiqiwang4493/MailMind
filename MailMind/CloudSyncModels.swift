import FirebaseFirestore
import Foundation

struct MailRecordDTO: Codable, Equatable {
    var id: String
    var ownerID: String
    var sourceTypeRawValue: String
    var sourceNames: [String]
    var pageCount: Int
    var summary: String
    var categoryRawValue: String
    var suggestedTodoTitles: [String]
    var suggestedTodoDeadlines: [Date]
    var createdAt: Date
    var updatedAt: Date

    init(record: MailRecord) {
        self.id = record.remoteID ?? UUID().uuidString
        self.ownerID = record.ownerID
        self.sourceTypeRawValue = record.sourceTypeRawValue
        self.sourceNames = record.sourceNames
        self.pageCount = record.pageCount
        self.summary = record.summary
        self.categoryRawValue = record.categoryRawValue
        self.suggestedTodoTitles = record.suggestedTodoTitles
        self.suggestedTodoDeadlines = record.suggestedTodoDeadlines
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let ownerID = data["ownerID"] as? String,
            let sourceTypeRawValue = data["sourceTypeRawValue"] as? String,
            let sourceNames = data["sourceNames"] as? [String],
            let pageCount = data["pageCount"] as? Int,
            let summary = data["summary"] as? String,
            let categoryRawValue = data["categoryRawValue"] as? String,
            let suggestedTodoTitles = data["suggestedTodoTitles"] as? [String],
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }

        self.id = id
        self.ownerID = ownerID
        self.sourceTypeRawValue = sourceTypeRawValue
        self.sourceNames = sourceNames
        self.pageCount = pageCount
        self.summary = summary
        self.categoryRawValue = categoryRawValue
        self.suggestedTodoTitles = suggestedTodoTitles
        self.suggestedTodoDeadlines = (data["suggestedTodoDeadlines"] as? [Timestamp])?.map { $0.dateValue() } ?? []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var firestoreData: [String: Any] {
        [
            "ownerID": ownerID,
            "sourceTypeRawValue": sourceTypeRawValue,
            "sourceNames": sourceNames,
            "pageCount": pageCount,
            "summary": summary,
            "categoryRawValue": categoryRawValue,
            "suggestedTodoTitles": suggestedTodoTitles,
            "suggestedTodoDeadlines": suggestedTodoDeadlines.map { Timestamp(date: $0) },
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
}

struct TodoItemDTO: Codable, Equatable {
    var id: String
    var ownerID: String
    var mailRecordID: String?
    var title: String
    var deadline: Date
    var mailSummary: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var updatedAt: Date

    init(todo: TodoItem) {
        self.id = todo.remoteID ?? UUID().uuidString
        self.ownerID = todo.ownerID
        self.mailRecordID = todo.mailRecord?.remoteID
        self.title = todo.title
        self.deadline = todo.deadline
        self.mailSummary = todo.mailSummary
        self.isCompleted = todo.isCompleted
        self.createdAt = todo.createdAt
        self.completedAt = todo.completedAt
        self.updatedAt = todo.updatedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let ownerID = data["ownerID"] as? String,
            let title = data["title"] as? String,
            let deadline = (data["deadline"] as? Timestamp)?.dateValue(),
            let mailSummary = data["mailSummary"] as? String,
            let isCompleted = data["isCompleted"] as? Bool,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }

        self.id = id
        self.ownerID = ownerID
        self.mailRecordID = data["mailRecordID"] as? String
        self.title = title
        self.deadline = deadline
        self.mailSummary = mailSummary
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        self.updatedAt = updatedAt
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "ownerID": ownerID,
            "title": title,
            "deadline": Timestamp(date: deadline),
            "mailSummary": mailSummary,
            "isCompleted": isCompleted,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let mailRecordID {
            data["mailRecordID"] = mailRecordID
        }
        if let completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        return data
    }
}
