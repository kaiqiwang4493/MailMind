import Foundation
import SwiftData
import Testing
@testable import MailMind

struct MailMindTests {
    @Test func pendingTodosSortByNearestDeadline() {
        let now = Date()
        let later = TodoItem(title: "Later", deadline: now.addingTimeInterval(300), mailSummary: "Later summary")
        let sooner = TodoItem(title: "Sooner", deadline: now.addingTimeInterval(100), mailSummary: "Sooner summary")
        let completed = TodoItem(title: "Done", deadline: now.addingTimeInterval(50), mailSummary: "Done summary", isCompleted: true)

        let sorted = [later, sooner, completed].pendingSortedByDeadline

        #expect(sorted.map(\.title) == ["Sooner", "Later"])
    }

    @Test func completingTodoMovesItOutOfPending() {
        let todo = TodoItem(title: "Pay bill", deadline: Date(), mailSummary: "Bill summary")

        todo.markCompleted(at: Date())

        #expect(todo.isCompleted)
        #expect(todo.completedAt != nil)
        #expect([todo].pendingSortedByDeadline.isEmpty)
    }

    @Test func mockAnalysisClassifiesCommonMailTypes() async throws {
        let service = MockMailAnalysisService()

        let bill = try await service.analyze(text: MockOCRService.sampleBillText, createdAt: Date())
        let government = try await service.analyze(text: MockOCRService.sampleGovernmentText, createdAt: Date())
        let insurance = try await service.analyze(text: MockOCRService.sampleInsuranceText, createdAt: Date())
        let advertisement = try await service.analyze(text: MockOCRService.sampleAdvertisementText, createdAt: Date())

        #expect(bill.category == .bill)
        #expect(!bill.todoDrafts.isEmpty)
        #expect(government.category == .government)
        #expect(!government.todoDrafts.isEmpty)
        #expect(insurance.category == .insurance)
        #expect(!insurance.todoDrafts.isEmpty)
        #expect(advertisement.category == .advertisement)
        #expect(advertisement.todoDrafts.isEmpty)
    }

    @Test @MainActor func multiPhotoInputCreatesOneMailRecord() throws {
        let container = try ModelContainer(
            for: MailRecord.self,
            TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let record = MailRecord(
            sourceType: .photos,
            sourceNames: ["Page 1", "Page 2", "Page 3"],
            pageCount: 3,
            extractedText: "Three combined pages",
            summary: "三页邮件合并成一封邮件。",
            category: .bill
        )

        context.insert(record)
        try context.save()

        let records = try context.fetch(FetchDescriptor<MailRecord>())
        #expect(records.count == 1)
        #expect(records.first?.pageCount == 3)
    }
}
