import Foundation
import PhotosUI
import PDFKit
import UniformTypeIdentifiers
import Vision
import UIKit

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

enum OCRServiceError: LocalizedError {
    case missingData
    case unreadableImage
    case unreadablePDF
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .missingData:
            "没有读取到文件内容。"
        case .unreadableImage:
            "无法读取这张照片。"
        case .unreadablePDF:
            "无法读取这个 PDF 文件。"
        case .noRecognizedText:
            "没有识别到英文文字，请换一张更清晰的照片或 PDF。"
        }
    }
}

struct VisionOCRService: OCRServicing {
    func extractText(from sources: [UploadedMailSource]) async throws -> String {
        var pageTexts: [String] = []

        for source in sources {
            switch source.type {
            case .sample:
                pageTexts.append(MockOCRService.sampleBillText)
            case .photos:
                guard let data = source.data else { throw OCRServiceError.missingData }
                pageTexts.append(try await recognizeImageData(data))
            case .pdf:
                guard let data = source.data else { throw OCRServiceError.missingData }
                pageTexts.append(try await extractPDFText(data))
            }
        }

        let combinedText = pageTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n--- Page Break ---\n\n")

        guard !combinedText.isEmpty else {
            throw OCRServiceError.noRecognizedText
        }

        return combinedText
    }

    private func recognizeImageData(_ data: Data) async throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw OCRServiceError.unreadableImage
        }

        return try await recognize(cgImage: cgImage)
    }

    private func extractPDFText(_ data: Data) async throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw OCRServiceError.unreadablePDF
        }

        if let embeddedText = document.string?.trimmingCharacters(in: .whitespacesAndNewlines), !embeddedText.isEmpty {
            return embeddedText
        }

        var pageTexts: [String] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(pageBounds)
                context.cgContext.translateBy(x: 0, y: pageBounds.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context.cgContext)
            }

            if let cgImage = image.cgImage {
                pageTexts.append(try await recognize(cgImage: cgImage))
            }
        }

        let recognizedText = pageTexts.joined(separator: "\n\n--- Page Break ---\n\n")
        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRServiceError.noRecognizedText
        }

        return recognizedText
    }

    private func recognize(cgImage: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            return request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
        }.value
    }
}
