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
            let createdAt = CloudDate.decode(data["createdAt"]),
            let updatedAt = CloudDate.decode(data["updatedAt"])
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
        self.suggestedTodoDeadlines = CloudDate.decodeArray(data["suggestedTodoDeadlines"])
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

    var callableData: [String: Any] {
        [
            "id": id,
            "ownerID": ownerID,
            "sourceTypeRawValue": sourceTypeRawValue,
            "sourceNames": sourceNames,
            "pageCount": pageCount,
            "summary": summary,
            "categoryRawValue": categoryRawValue,
            "suggestedTodoTitles": suggestedTodoTitles,
            "suggestedTodoDeadlines": suggestedTodoDeadlines.map(CloudDate.encode),
            "createdAt": CloudDate.encode(createdAt),
            "updatedAt": CloudDate.encode(updatedAt)
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
            let deadline = CloudDate.decode(data["deadline"]),
            let mailSummary = data["mailSummary"] as? String,
            let isCompleted = data["isCompleted"] as? Bool,
            let createdAt = CloudDate.decode(data["createdAt"]),
            let updatedAt = CloudDate.decode(data["updatedAt"])
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
        self.completedAt = CloudDate.decode(data["completedAt"])
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

    var callableData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "ownerID": ownerID,
            "title": title,
            "deadline": CloudDate.encode(deadline),
            "mailSummary": mailSummary,
            "isCompleted": isCompleted,
            "createdAt": CloudDate.encode(createdAt),
            "updatedAt": CloudDate.encode(updatedAt)
        ]

        if let mailRecordID {
            data["mailRecordID"] = mailRecordID
        }
        if let completedAt {
            data["completedAt"] = CloudDate.encode(completedAt)
        }

        return data
    }
}

enum CloudDate {
    static func encode(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func decode(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let string = value as? String {
            return iso8601Formatter.date(from: string) ?? fractionalISO8601Formatter.date(from: string)
        }
        return nil
    }

    static func decodeArray(_ value: Any?) -> [Date] {
        if let timestamps = value as? [Timestamp] {
            return timestamps.map { $0.dateValue() }
        }
        if let strings = value as? [String] {
            return strings.compactMap { decode($0) }
        }
        return []
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
