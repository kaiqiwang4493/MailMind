import FirebaseFunctions
import Foundation

struct BackendMailAnalysisService: MailAnalysisServicing {
    func analyze(text: String, createdAt: Date = .now) async throws -> MailAnalysisResult {
        let result = try await functions.httpsCallable("analyzeMail").call([
            "text": text,
            "createdAt": CloudDate.encode(createdAt)
        ])

        guard
            let data = result.data as? [String: Any],
            let summary = data["summary"] as? String,
            let categoryRawValue = data["category"] as? String,
            let category = MailCategory(rawValue: categoryRawValue),
            let rawTodos = data["todoItems"] as? [[String: Any]]
        else {
            throw MailAnalysisServiceError.invalidResponse
        }

        return MailAnalysisResult(
            summary: summary,
            category: category,
            todoDrafts: rawTodos.compactMap { rawTodo in
                guard let title = rawTodo["title"] as? String else {
                    return nil
                }
                return TodoDraft(
                    title: title,
                    deadline: Self.parseDeadline(rawTodo["deadline"], fallback: createdAt.addingTimeInterval(60 * 60 * 24 * 7))
                )
            }
        )
    }

    private var functions: Functions {
        Functions.functions(region: "us-central1")
    }

    private static func parseDeadline(_ value: Any?, fallback: Date) -> Date {
        if let string = value as? String {
            if let date = mailDateFormatter.date(from: string) {
                return date
            }
            return CloudDate.decode(string) ?? fallback
        }
        return fallback
    }

    private static let mailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
