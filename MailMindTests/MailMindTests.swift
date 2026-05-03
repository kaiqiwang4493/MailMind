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

    @Test @MainActor func suggestedTodosDoNotCreateTodoItemsUntilAdded() throws {
        let container = try ModelContainer(
            for: MailRecord.self,
            TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let draft = TodoDraft(title: "Pay renewal fee", deadline: Date())
        let record = MailRecord(
            sourceType: .pdf,
            sourceNames: ["DMV.pdf"],
            pageCount: 2,
            extractedText: "Renewal notice",
            summary: "这是一封续费通知。",
            category: .government,
            suggestedTodos: [draft]
        )

        context.insert(record)
        try context.save()

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(record.suggestedTodos.count == 1)
        #expect(todos.isEmpty)
    }

    @Test @MainActor func guestRecordsAndTodosUseGuestOwner() throws {
        let todo = TodoItem(title: "Guest todo", deadline: Date(), mailSummary: "Guest summary")
        let record = MailRecord(
            sourceType: .sample,
            sourceNames: ["Sample"],
            pageCount: 1,
            extractedText: "Sample",
            summary: "访客摘要。",
            category: .bill,
            todoItems: [todo]
        )

        #expect(record.ownerID == AuthSession.guestOwnerID)
        #expect(todo.ownerID == AuthSession.guestOwnerID)
    }

    @Test @MainActor func localFilteringUsesCurrentOwner() {
        let userRecord = MailRecord(ownerID: "user-1", sourceType: .sample, sourceNames: ["User"], pageCount: 1, extractedText: "User", summary: "用户摘要。", category: .bill)
        let guestRecord = MailRecord(ownerID: AuthSession.guestOwnerID, sourceType: .sample, sourceNames: ["Guest"], pageCount: 1, extractedText: "Guest", summary: "访客摘要。", category: .bill)

        let visibleRecords = [userRecord, guestRecord].filter { $0.ownerID == "user-1" }

        #expect(visibleRecords.map(\.summary) == ["用户摘要。"])
    }

    @Test @MainActor func exitingGuestDeletesGuestData() throws {
        let container = try ModelContainer(
            for: MailRecord.self,
            TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let session = AuthSession()
        session.continueAsGuest()
        context.insert(MailRecord(sourceType: .sample, sourceNames: ["Guest"], pageCount: 1, extractedText: "Guest", summary: "访客摘要。", category: .bill))
        context.insert(TodoItem(title: "Guest todo", deadline: Date(), mailSummary: "Guest summary"))
        try context.save()

        session.exitGuest(modelContext: context)

        #expect(try context.fetch(FetchDescriptor<MailRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TodoItem>()).isEmpty)
        #expect(session.state == .signedOut)
    }

    @Test @MainActor func guestMigrationAssignsAuthenticatedOwnerAndRemoteIDs() throws {
        let container = try ModelContainer(
            for: MailRecord.self,
            TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let session = AuthSession()
        session.continueAsGuest()
        let record = MailRecord(sourceType: .sample, sourceNames: ["Guest"], pageCount: 1, extractedText: "Guest", summary: "访客摘要。", category: .bill)
        let todo = TodoItem(title: "Guest todo", deadline: Date(), mailSummary: "Guest summary", mailRecord: record)
        record.todoItems.append(todo)
        context.insert(record)
        context.insert(todo)
        try context.save()

        try session.signInForTesting(uid: "user-1", modelContext: context)

        #expect(record.ownerID == "user-1")
        #expect(todo.ownerID == "user-1")
        #expect(record.remoteID != nil)
        #expect(todo.remoteID != nil)
    }

    @Test @MainActor func restoreWithoutFirebaseUserLeavesLoginVisible() async throws {
        let container = try inMemoryContainer()
        let settings = InMemoryFaceIDUnlockSettingsStore()
        settings.isFaceIDUnlockEnabled = true
        settings.lastAuthenticatedProvider = .google
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(),
            faceIDSettingsStore: settings,
            firebaseCurrentUserUIDProvider: { nil },
            skipsFirebaseAuthValidation: true
        )

        await session.restoreSessionIfNeeded(modelContext: container.mainContext)

        #expect(session.state == .signedOut)
    }

    @Test @MainActor func restoreWithFaceIDDisabledDoesNotRequireUnlock() async throws {
        let container = try inMemoryContainer()
        let settings = InMemoryFaceIDUnlockSettingsStore()
        settings.lastAuthenticatedProvider = .google
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(),
            faceIDSettingsStore: settings,
            firebaseCurrentUserUIDProvider: { "user-1" },
            skipsFirebaseAuthValidation: true
        )

        await session.restoreSessionIfNeeded(modelContext: container.mainContext)

        #expect(session.state == .signedOut)
    }

    @Test @MainActor func restoreWithFaceIDEnabledRequiresLocalUnlock() async throws {
        let container = try inMemoryContainer()
        let settings = InMemoryFaceIDUnlockSettingsStore()
        settings.isFaceIDUnlockEnabled = true
        settings.lastAuthenticatedProvider = .apple
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(),
            faceIDSettingsStore: settings,
            firebaseCurrentUserUIDProvider: { "user-1" },
            skipsFirebaseAuthValidation: true
        )

        await session.restoreSessionIfNeeded(modelContext: container.mainContext)

        #expect(session.state == .localUnlockRequired(uid: "user-1", provider: .apple))
    }

    @Test @MainActor func successfulFaceIDUnlockRestoresAuthenticatedSession() async throws {
        let container = try inMemoryContainer()
        let settings = InMemoryFaceIDUnlockSettingsStore()
        settings.isFaceIDUnlockEnabled = true
        settings.lastAuthenticatedProvider = .google
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(authenticationSucceeds: true),
            faceIDSettingsStore: settings,
            firebaseCurrentUserUIDProvider: { "user-1" },
            skipsFirebaseAuthValidation: true
        )

        await session.restoreSessionIfNeeded(modelContext: container.mainContext)
        await session.unlockWithFaceID(modelContext: container.mainContext)

        #expect(session.state == .authenticated(uid: "user-1", provider: .google))
    }

    @Test @MainActor func failedFaceIDUnlockKeepsSessionAvailableForRetry() async throws {
        let container = try inMemoryContainer()
        let settings = InMemoryFaceIDUnlockSettingsStore()
        settings.isFaceIDUnlockEnabled = true
        settings.lastAuthenticatedProvider = .google
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(authenticationSucceeds: false),
            faceIDSettingsStore: settings,
            firebaseCurrentUserUIDProvider: { "user-1" },
            skipsFirebaseAuthValidation: true
        )

        await session.restoreSessionIfNeeded(modelContext: container.mainContext)
        await session.unlockWithFaceID(modelContext: container.mainContext)

        #expect(session.state == .localUnlockRequired(uid: "user-1", provider: .google))
        #expect(settings.isFaceIDUnlockEnabled)
        #expect(settings.lastAuthenticatedProvider == .google)
    }

    @Test @MainActor func enablingFaceIDFromAccountRequiresSuccessfulBiometricVerification() async throws {
        let settings = InMemoryFaceIDUnlockSettingsStore()
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(authenticationSucceeds: true),
            faceIDSettingsStore: settings,
            skipsFirebaseAuthValidation: true
        )

        try session.signInForTesting(uid: "user-1", modelContext: try inMemoryContainer().mainContext)
        await session.updateFaceIDUnlockFromAccount(isEnabled: true)

        #expect(session.isFaceIDUnlockEnabled)
        #expect(settings.lastAuthenticatedProvider == .mock)
    }

    @Test @MainActor func failedAccountFaceIDVerificationLeavesSwitchOff() async throws {
        let settings = InMemoryFaceIDUnlockSettingsStore()
        let session = AuthSession(
            cloudSyncService: MockCloudSyncService(),
            biometricAuthenticator: MockBiometricAuthenticator(authenticationSucceeds: false),
            faceIDSettingsStore: settings,
            skipsFirebaseAuthValidation: true
        )

        try session.signInForTesting(uid: "user-1", modelContext: try inMemoryContainer().mainContext)
        await session.updateFaceIDUnlockFromAccount(isEnabled: true)

        #expect(!session.isFaceIDUnlockEnabled)
        #expect(!settings.isFaceIDUnlockEnabled)
    }

    @Test func syncDTOsMirrorLocalModels() {
        let record = MailRecord(ownerID: "user-1", remoteID: "mail-1", sourceType: .sample, sourceNames: ["Sample"], pageCount: 1, extractedText: "Private OCR", summary: "同步摘要。", category: .government)
        let todo = TodoItem(ownerID: "user-1", remoteID: "todo-1", title: "Pay fee", deadline: Date(), mailSummary: "同步摘要。", mailRecord: record)

        let recordDTO = MailRecordDTO(record: record)
        let todoDTO = TodoItemDTO(todo: todo)

        #expect(recordDTO.id == "mail-1")
        #expect(recordDTO.ownerID == "user-1")
        #expect(recordDTO.summary == "同步摘要。")
        #expect(todoDTO.id == "todo-1")
        #expect(todoDTO.ownerID == "user-1")
        #expect(todoDTO.mailRecordID == "mail-1")
    }

    @MainActor
    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MailRecord.self,
            TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

private struct MockBiometricAuthenticator: LocalBiometricAuthenticating {
    var canUseFaceIDResult = true
    var authenticationSucceeds = true

    func canUseFaceID() -> Bool {
        canUseFaceIDResult
    }

    func authenticateForMailMindUnlock() async throws {
        if !authenticationSucceeds {
            throw AuthSessionError.faceIDAuthenticationFailed
        }
    }
}

private final class InMemoryFaceIDUnlockSettingsStore: FaceIDUnlockSettingsStoring {
    var isFaceIDUnlockEnabled = false
    var lastAuthenticatedProvider: AuthProvider?

    func clear() {
        isFaceIDUnlockEnabled = false
        lastAuthenticatedProvider = nil
    }
}

private struct MockCloudSyncService: CloudSyncServicing {
    func loadMailRecords(ownerID: String) async throws -> [MailRecordDTO] {
        []
    }

    func loadTodoItems(ownerID: String) async throws -> [TodoItemDTO] {
        []
    }

    func saveMailRecord(_ record: MailRecordDTO, ownerID: String) async throws {}
    func saveTodoItem(_ todo: TodoItemDTO, ownerID: String) async throws {}
    func deleteTodoItem(remoteID: String, ownerID: String) async throws {}
}
