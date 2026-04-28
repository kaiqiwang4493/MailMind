import Foundation

struct TodoDraft: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var deadline: Date
}

struct MailAnalysisResult: Equatable {
    var summary: String
    var category: MailCategory
    var todoDrafts: [TodoDraft]
}

protocol MailAnalysisServicing {
    func analyze(text: String, createdAt: Date) async throws -> MailAnalysisResult
}

enum MailAnalysisServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case unsupportedCategory(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先在设置中填写 OpenAI API Key。"
        case .invalidResponse:
            "AI 返回结果格式不正确，请稍后再试。"
        case .unsupportedCategory(let category):
            "AI 返回了不支持的邮件类别：\(category)"
        }
    }
}

struct OpenAIConfiguration {
    var apiKey: String
    var model: String
}

struct OpenAIMailAnalysisService: MailAnalysisServicing {
    var configuration: OpenAIConfiguration

    func analyze(text: String, createdAt: Date = .now) async throws -> MailAnalysisResult {
        let trimmedAPIKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw MailAnalysisServiceError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIResponsesRequest(
            model: configuration.model,
            input: [
                .init(role: "system", content: [
                    .init(text: """
                    You analyze English physical mail for Chinese-speaking older adults.
                    Return concise Simplified Chinese. Extract only action items that the recipient actually needs to do.
                    If the mail does not require action, return an empty todoItems array.
                    Deadlines must use ISO date format YYYY-MM-DD. If the mail has no clear deadline, use null.
                    Categories must be one of: bill, government, banking, insurance, healthcare, tax, legal, school, advertisement, personal, other.
                    Current date: \(Self.dateFormatter.string(from: createdAt)).
                    """)
                ]),
                .init(role: "user", content: [
                    .init(text: "Analyze this OCR text from one mail item:\n\n\(text)")
                ])
            ],
            text: .structuredMailAnalysis
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "OpenAIMailAnalysisService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let responseObject = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        guard let outputText = responseObject.outputText else {
            throw MailAnalysisServiceError.invalidResponse
        }

        let aiResult = try JSONDecoder().decode(OpenAIMailAnalysisPayload.self, from: Data(outputText.utf8))
        guard let category = MailCategory(rawValue: aiResult.category) else {
            throw MailAnalysisServiceError.unsupportedCategory(aiResult.category)
        }

        return MailAnalysisResult(
            summary: aiResult.summary,
            category: category,
            todoDrafts: aiResult.todoItems.map {
                TodoDraft(
                    title: $0.title,
                    deadline: Self.parseDeadline($0.deadline, fallback: createdAt.addingTimeInterval(60 * 60 * 24 * 7))
                )
            }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func parseDeadline(_ value: String?, fallback: Date) -> Date {
        guard let value, let date = dateFormatter.date(from: value) else {
            return fallback
        }
        return date
    }
}

private struct OpenAIResponsesRequest: Encodable {
    var model: String
    var input: [InputMessage]
    var text: TextConfiguration

    struct InputMessage: Encodable {
        var role: String
        var content: [InputContent]
    }

    struct InputContent: Encodable {
        var type = "input_text"
        var text: String
    }

    struct TextConfiguration: Encodable {
        var format: ResponseFormat

        static let structuredMailAnalysis = TextConfiguration(format: ResponseFormat(
            type: "json_schema",
            name: "mail_analysis",
            strict: true,
            schema: .object([
                "type": .string("object"),
                "additionalProperties": .bool(false),
                "required": .array([.string("summary"), .string("category"), .string("todoItems")]),
                "properties": .object([
                    "summary": .object([
                        "type": .string("string"),
                        "description": .string("A short Simplified Chinese summary of the English mail.")
                    ]),
                    "category": .object([
                        "type": .string("string"),
                        "enum": .array(MailCategory.allCases.map { .string($0.rawValue) })
                    ]),
                    "todoItems": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("object"),
                            "additionalProperties": .bool(false),
                            "required": .array([.string("title"), .string("deadline")]),
                            "properties": .object([
                                "title": .object([
                                    "type": .string("string"),
                                    "description": .string("A concise Simplified Chinese action item.")
                                ]),
                                "deadline": .object([
                                    "anyOf": .array([
                                        .object(["type": .string("string")]),
                                        .object(["type": .string("null")])
                                    ]),
                                    "description": .string("ISO date YYYY-MM-DD if present, otherwise null.")
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ))
    }

    struct ResponseFormat: Encodable {
        var type: String
        var name: String
        var strict: Bool
        var schema: JSONValue
    }
}

private enum JSONValue: Encodable {
    case string(String)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

private struct OpenAIResponsesResponse: Decodable {
    var output: [OutputItem]

    var outputText: String? {
        output
            .flatMap(\.content)
            .first { $0.type == "output_text" }?
            .text
    }

    struct OutputItem: Decodable {
        var content: [OutputContent]

        enum CodingKeys: String, CodingKey {
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = (try? container.decode([OutputContent].self, forKey: .content)) ?? []
        }
    }

    struct OutputContent: Decodable {
        var type: String
        var text: String?
    }
}

private struct OpenAIMailAnalysisPayload: Decodable {
    var summary: String
    var category: String
    var todoItems: [TodoPayload]

    struct TodoPayload: Decodable {
        var title: String
        var deadline: String?
    }
}

struct MockMailAnalysisService: MailAnalysisServicing {
    func analyze(text: String, createdAt: Date = .now) async throws -> MailAnalysisResult {
        let lowercasedText = text.lowercased()

        if lowercasedText.contains("premium") || lowercasedText.contains("insurance") {
            return MailAnalysisResult(
                summary: "这封邮件来自保险公司，主要说明保费或保险资料需要处理。请重点查看金额、截止日期和联系方式。",
                category: .insurance,
                todoDrafts: [
                    TodoDraft(title: "查看保险邮件并确认是否需要付款或更新资料", deadline: createdAt.addingTimeInterval(60 * 60 * 24 * 10))
                ]
            )
        }

        if lowercasedText.contains("irs") || lowercasedText.contains("tax") || lowercasedText.contains("government") {
            return MailAnalysisResult(
                summary: "这封邮件看起来是政府或税务相关通知，可能要求你确认信息、回复材料或在截止日期前完成处理。",
                category: .government,
                todoDrafts: [
                    TodoDraft(title: "查看政府邮件要求并准备需要提交的资料", deadline: createdAt.addingTimeInterval(60 * 60 * 24 * 14))
                ]
            )
        }

        if lowercasedText.contains("invoice") || lowercasedText.contains("payment") || lowercasedText.contains("due") || lowercasedText.contains("balance") {
            return MailAnalysisResult(
                summary: "这封邮件是一份账单或付款提醒，说明有一笔费用需要在截止日期前支付。建议核对金额和付款方式。",
                category: .bill,
                todoDrafts: [
                    TodoDraft(title: "核对账单金额并完成付款", deadline: createdAt.addingTimeInterval(60 * 60 * 24 * 7))
                ]
            )
        }

        if lowercasedText.contains("sale") || lowercasedText.contains("offer") || lowercasedText.contains("discount") || lowercasedText.contains("promotion") {
            return MailAnalysisResult(
                summary: "这封邮件主要是促销或广告信息，介绍优惠、折扣或活动内容。通常不需要你必须处理。",
                category: .advertisement,
                todoDrafts: []
            )
        }

        return MailAnalysisResult(
            summary: "这封英文邮件包含一般通知信息。请查看原文中的日期、金额、电话和回复要求，以确认是否需要进一步处理。",
            category: .other,
            todoDrafts: []
        )
    }
}
