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
