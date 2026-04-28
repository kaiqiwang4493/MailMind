import Foundation
import PhotosUI
import UniformTypeIdentifiers

struct UploadedMailSource: Identifiable, Equatable {
    let id = UUID()
    var type: MailSourceType
    var displayName: String
    var pageCount: Int
    var data: Data?
}

protocol OCRServicing {
    func extractText(from sources: [UploadedMailSource]) async throws -> String
}

struct MockOCRService: OCRServicing {
    func extractText(from sources: [UploadedMailSource]) async throws -> String {
        let names = sources.map(\.displayName).joined(separator: ", ")
        let totalPages = sources.reduce(0) { $0 + max($1.pageCount, 1) }

        if sources.contains(where: { $0.type == .sample }) {
            return Self.sampleBillText
        }

        if names.lowercased().contains("insurance") {
            return Self.sampleInsuranceText
        }

        if names.lowercased().contains("tax") || names.lowercased().contains("irs") {
            return Self.sampleGovernmentText
        }

        if names.lowercased().contains("sale") || names.lowercased().contains("offer") {
            return Self.sampleAdvertisementText
        }

        return """
        MailMind mock OCR combined \(totalPages) page(s) from \(names).
        Payment reminder: Your account has a balance due. Please submit payment by the due date shown on your statement.
        """
    }

    static let sampleBillText = """
    Utility Services Statement
    Account balance: $86.42
    Payment due: May 10, 2026
    Please pay your balance online or by phone to avoid a late fee.
    """

    static let sampleGovernmentText = """
    Government notice
    Please review your records and respond within 14 days. Additional tax information may be required.
    """

    static let sampleInsuranceText = """
    Insurance premium notice
    Your premium payment is due soon. Please call the customer service number if your policy information has changed.
    """

    static let sampleAdvertisementText = """
    Spring sale offer
    Save 25 percent on selected items this week. No action is required.
    """
}
