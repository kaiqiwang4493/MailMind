import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import LocalAuthentication
import Security
import SwiftData
import SwiftUI
import UIKit

enum AuthProvider: String, Codable {
    case apple
    case google
    case mock

    var displayName: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .mock: "测试账号"
        }
    }
}

enum AuthState: Equatable {
    case signedOut
    case guest
    case localUnlockRequired(uid: String, provider: AuthProvider)
    case authenticated(uid: String, provider: AuthProvider)

    var ownerID: String? {
        switch self {
        case .signedOut:
            nil
        case .guest:
            AuthSession.guestOwnerID
        case .localUnlockRequired:
            nil
        case .authenticated(let uid, _):
            uid
        }
    }

    var displayName: String {
        switch self {
        case .signedOut:
            "未登录"
        case .guest:
            "访客"
        case .localUnlockRequired:
            "需要 Face ID 解锁"
        case .authenticated(_, let provider):
            "\(provider.displayName) 账号"
        }
    }

    var isGuest: Bool {
        self == .guest
    }

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    var requiresLocalUnlock: Bool {
        if case .localUnlockRequired = self {
            return true
        }
        return false
    }
}

enum AuthSessionError: LocalizedError {
    case providerUnavailable(String)
    case signedOut
    case missingFirebaseClientID
    case missingGoogleToken
    case missingPresentationContext
    case missingFirebaseUser
    case missingAppleIdentityToken
    case invalidAppleIdentityToken
    case faceIDUnavailable
    case faceIDAuthenticationFailed

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let provider):
            "\(provider) 登录还需要完成 Firebase 配置。"
        case .signedOut:
            "请先登录或使用访客模式。"
        case .missingFirebaseClientID:
            "没有找到 Firebase Google Client ID，请确认 GoogleService-Info.plist 已加入 App target。"
        case .missingGoogleToken:
            "Google 登录没有返回有效凭证，请重试。"
        case .missingPresentationContext:
            "暂时无法打开 Google 登录页面，请稍后重试。"
        case .missingFirebaseUser:
            "Firebase 登录状态还没有准备好，请重新登录后再试。"
        case .missingAppleIdentityToken:
            "Apple 登录没有返回有效凭证，请重试。"
        case .invalidAppleIdentityToken:
            "Apple 登录凭证格式无效，请重试。"
        case .faceIDUnavailable:
            "这台设备暂时无法使用 Face ID。"
        case .faceIDAuthenticationFailed:
            "Face ID 验证失败，请重试。"
        }
    }
}

protocol LocalBiometricAuthenticating {
    func canUseFaceID() -> Bool
    func authenticateForMailMindUnlock() async throws
}

struct LocalBiometricAuthenticator: LocalBiometricAuthenticating {
    func canUseFaceID() -> Bool {
        if CommandLine.arguments.contains("-uiTestingFaceIDUnavailable") {
            return false
        }

        if CommandLine.arguments.contains("-uiTestingFaceIDSuccess") ||
            CommandLine.arguments.contains("-uiTestingFaceIDFailure") {
            return true
        }

        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            && context.biometryType == .faceID
    }

    func authenticateForMailMindUnlock() async throws {
        if CommandLine.arguments.contains("-uiTestingFaceIDSuccess") {
            return
        }

        if CommandLine.arguments.contains("-uiTestingFaceIDFailure") ||
            CommandLine.arguments.contains("-uiTestingFaceIDUnavailable") {
            throw AuthSessionError.faceIDAuthenticationFailed
        }

        let context = LAContext()
        context.localizedCancelTitle = "重新验证登陆"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .faceID else {
            throw AuthSessionError.faceIDUnavailable
        }

        let didAuthenticate = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "使用 Face ID 解锁 MailMind"
        )
        if !didAuthenticate {
            throw AuthSessionError.faceIDAuthenticationFailed
        }
    }
}

protocol FaceIDUnlockSettingsStoring {
    var isFaceIDUnlockEnabled: Bool { get set }
    var lastAuthenticatedProvider: AuthProvider? { get set }
    func clear()
}

struct UserDefaultsFaceIDUnlockSettingsStore: FaceIDUnlockSettingsStoring {
    private enum Key {
        static let isEnabled = "MailMind.isFaceIDUnlockEnabled"
        static let provider = "MailMind.lastAuthenticatedProvider"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if CommandLine.arguments.contains("-uiTestingResetStore") {
            self.userDefaults.removeObject(forKey: Key.isEnabled)
            self.userDefaults.removeObject(forKey: Key.provider)
        }
        if CommandLine.arguments.contains("-uiTestingFaceIDEnabled") {
            self.userDefaults.set(true, forKey: Key.isEnabled)
            self.userDefaults.set(AuthProvider.google.rawValue, forKey: Key.provider)
        }
    }

    var isFaceIDUnlockEnabled: Bool {
        get { userDefaults.bool(forKey: Key.isEnabled) }
        set { userDefaults.set(newValue, forKey: Key.isEnabled) }
    }

    var lastAuthenticatedProvider: AuthProvider? {
        get {
            userDefaults.string(forKey: Key.provider).flatMap(AuthProvider.init(rawValue:))
        }
        set {
            if let newValue {
                userDefaults.set(newValue.rawValue, forKey: Key.provider)
            } else {
                userDefaults.removeObject(forKey: Key.provider)
            }
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.isEnabled)
        userDefaults.removeObject(forKey: Key.provider)
    }
}

@MainActor
final class AuthSession: ObservableObject {
    nonisolated static let guestOwnerID = "guest"

    @Published private(set) var state: AuthState = .signedOut
    @Published var authError: String?
    @Published var shouldOfferFaceIDUnlock = false
    @Published private(set) var isFaceIDUnlockEnabled = false
    private let cloudSyncService: CloudSyncServicing
    private let biometricAuthenticator: LocalBiometricAuthenticating
    private var faceIDSettingsStore: FaceIDUnlockSettingsStoring
    private let firebaseCurrentUserUIDProvider: () -> String?
    private let skipsFirebaseAuthValidation: Bool
    private var appleSignInCoordinator: AppleSignInCoordinator?

    init() {
        self.cloudSyncService = FirestoreCloudSyncService()
        self.biometricAuthenticator = LocalBiometricAuthenticator()
        self.faceIDSettingsStore = UserDefaultsFaceIDUnlockSettingsStore()
        self.isFaceIDUnlockEnabled = faceIDSettingsStore.isFaceIDUnlockEnabled
        self.firebaseCurrentUserUIDProvider = {
            if CommandLine.arguments.contains("-uiTestingExistingAuth") {
                return "ui-test-user"
            }
            return Auth.auth().currentUser?.uid
        }
        self.skipsFirebaseAuthValidation = false
    }

    init(
        cloudSyncService: CloudSyncServicing,
        biometricAuthenticator: LocalBiometricAuthenticating = LocalBiometricAuthenticator(),
        faceIDSettingsStore: FaceIDUnlockSettingsStoring = UserDefaultsFaceIDUnlockSettingsStore(),
        firebaseCurrentUserUIDProvider: @escaping () -> String? = {
            if CommandLine.arguments.contains("-uiTestingExistingAuth") {
                return "ui-test-user"
            }
            return Auth.auth().currentUser?.uid
        },
        skipsFirebaseAuthValidation: Bool = false
    ) {
        self.cloudSyncService = cloudSyncService
        self.biometricAuthenticator = biometricAuthenticator
        self.faceIDSettingsStore = faceIDSettingsStore
        self.isFaceIDUnlockEnabled = faceIDSettingsStore.isFaceIDUnlockEnabled
        self.firebaseCurrentUserUIDProvider = firebaseCurrentUserUIDProvider
        self.skipsFirebaseAuthValidation = skipsFirebaseAuthValidation
    }

    var ownerID: String? {
        state.ownerID
    }

    var isSignedInOrGuest: Bool {
        ownerID != nil
    }

    func continueAsGuest() {
        state = .guest
    }

    func restoreSessionIfNeeded(modelContext: ModelContext) async {
        guard state == .signedOut,
              let uid = firebaseCurrentUserUIDProvider() else {
            return
        }

        guard faceIDSettingsStore.isFaceIDUnlockEnabled,
              let provider = faceIDSettingsStore.lastAuthenticatedProvider else {
            resetExternalSignInState()
            return
        }

        state = .localUnlockRequired(uid: uid, provider: provider)
    }

    func unlockWithFaceID(modelContext: ModelContext) async {
        guard case .localUnlockRequired(let uid, let provider) = state else {
            return
        }

        do {
            try await biometricAuthenticator.authenticateForMailMindUnlock()
            try await prepareFirebaseAuthForCloud(uid: uid)
            state = .authenticated(uid: uid, provider: provider)
            clearLocalCache(modelContext: modelContext)
            try await loadCloudData(for: uid, modelContext: modelContext)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signInAgainFromLocalUnlock(modelContext: ModelContext) {
        resetExternalSignInState()
        faceIDSettingsStore.clear()
        isFaceIDUnlockEnabled = false
        clearLocalCache(modelContext: modelContext)
        state = .signedOut
    }

    func enableFaceIDUnlock() {
        guard case .authenticated(_, let provider) = state else {
            return
        }

        guard biometricAuthenticator.canUseFaceID() else {
            authError = AuthSessionError.faceIDUnavailable.localizedDescription
            shouldOfferFaceIDUnlock = false
            return
        }

        faceIDSettingsStore.lastAuthenticatedProvider = provider
        setFaceIDUnlockEnabled(true)
        shouldOfferFaceIDUnlock = false
    }

    func skipFaceIDUnlockOffer() {
        shouldOfferFaceIDUnlock = false
    }

    func updateFaceIDUnlockFromAccount(isEnabled: Bool) async {
        guard case .authenticated(_, let provider) = state else {
            setFaceIDUnlockEnabled(false)
            return
        }

        if isEnabled {
            do {
                try await biometricAuthenticator.authenticateForMailMindUnlock()
                faceIDSettingsStore.lastAuthenticatedProvider = provider
                setFaceIDUnlockEnabled(true)
            } catch {
                authError = error.localizedDescription
                setFaceIDUnlockEnabled(false)
            }
        } else {
            setFaceIDUnlockEnabled(false)
        }
    }

    func signInWithApple(modelContext: ModelContext) async {
        await signIn(provider: .apple, modelContext: modelContext)
    }

    func signInWithGoogle(modelContext: ModelContext) async {
        await signIn(provider: .google, modelContext: modelContext)
    }

    func signOut(modelContext: ModelContext) {
        resetExternalSignInState()
        faceIDSettingsStore.clear()
        isFaceIDUnlockEnabled = false
        shouldOfferFaceIDUnlock = false
        clearLocalCache(modelContext: modelContext)
        state = .signedOut
    }

    func signOutFromPresentedUI(modelContext: ModelContext) {
        resetExternalSignInState()
        faceIDSettingsStore.clear()
        isFaceIDUnlockEnabled = false
        shouldOfferFaceIDUnlock = false
        state = .signedOut
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.clearLocalCache(modelContext: modelContext)
        }
    }

    func signInForTesting(uid: String, modelContext: ModelContext) throws {
        let wasGuest = state.isGuest
        state = .authenticated(uid: uid, provider: .mock)
        if wasGuest {
            try migrateGuestData(to: uid, modelContext: modelContext)
        }
    }

    func saveMailRecordToCloud(_ record: MailRecord) {
        guard let ownerID = cloudSyncOwnerID else { return }
        if record.remoteID == nil {
            record.remoteID = UUID().uuidString
        }
        record.updatedAt = .now
        let dto = MailRecordDTO(record: record)
        Task {
            await runCloudOperation {
                try await self.cloudSyncService.saveMailRecord(dto, ownerID: ownerID)
            }
        }
    }

    func saveTodoItemToCloud(_ todo: TodoItem) {
        guard let ownerID = cloudSyncOwnerID else { return }
        if todo.remoteID == nil {
            todo.remoteID = UUID().uuidString
        }
        todo.updatedAt = .now
        let dto = TodoItemDTO(todo: todo)
        Task {
            await runCloudOperation {
                try await self.cloudSyncService.saveTodoItem(dto, ownerID: ownerID)
            }
        }
    }

    func deleteTodoItemFromCloud(_ todo: TodoItem) {
        guard let ownerID = cloudSyncOwnerID, let remoteID = todo.remoteID else { return }
        Task {
            await runCloudOperation {
                try await self.cloudSyncService.deleteTodoItem(remoteID: remoteID, ownerID: ownerID)
            }
        }
    }

    func exitGuest(modelContext: ModelContext) {
        deleteData(ownerID: Self.guestOwnerID, modelContext: modelContext)
        state = .signedOut
    }

    func exitGuestFromPresentedUI(modelContext: ModelContext) {
        state = .signedOut
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.deleteData(ownerID: Self.guestOwnerID, modelContext: modelContext)
        }
    }

    private func signIn(provider: AuthProvider, modelContext: ModelContext) async {
        do {
            let wasGuest = state.isGuest
            let uid = try await authenticate(provider: provider)
            try await prepareFirebaseAuthForCloud(uid: uid)
            state = .authenticated(uid: uid, provider: provider)
            faceIDSettingsStore.lastAuthenticatedProvider = provider
            isFaceIDUnlockEnabled = faceIDSettingsStore.isFaceIDUnlockEnabled

            if wasGuest {
                try migrateGuestData(to: uid, modelContext: modelContext)
                try await uploadLocalData(for: uid, modelContext: modelContext)
            } else {
                clearLocalCache(modelContext: modelContext)
                try await loadCloudData(for: uid, modelContext: modelContext)
            }

            if shouldPromptForFaceIDUnlock(provider: provider) {
                shouldOfferFaceIDUnlock = true
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    private func authenticate(provider: AuthProvider) async throws -> String {
        if CommandLine.arguments.contains("-uiTestingMockAuth") {
            return "ui-test-user"
        }

        switch provider {
        case .google:
            return try await authenticateWithGoogle()
        case .apple:
            return try await authenticateWithApple()
        case .mock:
            throw AuthSessionError.providerUnavailable(provider.displayName)
        }
    }

    private func authenticateWithApple() async throws -> String {
        resetExternalSignInState()

        let nonce = Self.randomNonceString()
        let appleIDCredential = try await requestAppleCredential(nonce: nonce)

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthSessionError.missingAppleIdentityToken
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthSessionError.invalidAppleIdentityToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user.uid
    }

    private func requestAppleCredential(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        guard let presentationAnchor = UIApplication.shared.mailMindPresentationAnchor else {
            throw AuthSessionError.missingPresentationContext
        }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = AppleSignInCoordinator(
                presentationAnchor: presentationAnchor,
                controller: controller
            ) { [weak self] result in
                self?.appleSignInCoordinator = nil
                continuation.resume(with: result)
            }

            appleSignInCoordinator = coordinator
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
    }

    private func authenticateWithGoogle() async throws -> String {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthSessionError.missingFirebaseClientID
        }

        resetExternalSignInState()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presentingViewController = UIApplication.shared.mailMindRootViewController else {
            throw AuthSessionError.missingPresentationContext
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthSessionError.missingGoogleToken
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user.uid
    }

    private func prepareFirebaseAuthForCloud(uid: String) async throws {
        guard !CommandLine.arguments.contains("-uiTestingMockAuth"),
              !CommandLine.arguments.contains("-uiTestingExistingAuth"),
              !skipsFirebaseAuthValidation else {
            return
        }

        guard let user = Auth.auth().currentUser, user.uid == uid else {
            throw AuthSessionError.missingFirebaseUser
        }

        _ = try await user.getIDToken(forcingRefresh: true)
    }

    private func resetExternalSignInState() {
        guard !CommandLine.arguments.contains("-uiTestingMockAuth") else {
            return
        }

        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private func migrateGuestData(to uid: String, modelContext: ModelContext) throws {
        let guestRecords = try modelContext.fetch(FetchDescriptor<MailRecord>()).filter { $0.ownerID == Self.guestOwnerID }
        for record in guestRecords {
            record.ownerID = uid
            record.remoteID = record.remoteID ?? UUID().uuidString
            record.updatedAt = .now
        }

        let guestTodos = try modelContext.fetch(FetchDescriptor<TodoItem>()).filter { $0.ownerID == Self.guestOwnerID }
        for todo in guestTodos {
            todo.ownerID = uid
            todo.remoteID = todo.remoteID ?? UUID().uuidString
            todo.updatedAt = .now
        }

        try modelContext.save()
    }

    private func loadCloudData(for uid: String, modelContext: ModelContext) async throws {
        guard shouldUseCloudSync else { return }

        let recordDTOs = try await cloudSyncService.loadMailRecords(ownerID: uid)
        var recordsByRemoteID: [String: MailRecord] = [:]

        for dto in recordDTOs {
            let record = MailRecord(
                ownerID: dto.ownerID,
                remoteID: dto.id,
                sourceType: MailSourceType(rawValue: dto.sourceTypeRawValue) ?? .sample,
                sourceNames: dto.sourceNames,
                pageCount: dto.pageCount,
                extractedText: "",
                summary: dto.summary,
                category: MailCategory(rawValue: dto.categoryRawValue) ?? .other,
                suggestedTodos: dto.suggestedTodoDrafts,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            recordsByRemoteID[dto.id] = record
            modelContext.insert(record)
        }

        let todoDTOs = try await cloudSyncService.loadTodoItems(ownerID: uid)
        for dto in todoDTOs {
            let todo = TodoItem(
                ownerID: dto.ownerID,
                remoteID: dto.id,
                title: dto.title,
                deadline: dto.deadline,
                mailSummary: dto.mailSummary,
                isCompleted: dto.isCompleted,
                createdAt: dto.createdAt,
                completedAt: dto.completedAt,
                updatedAt: dto.updatedAt,
                mailRecord: dto.mailRecordID.flatMap { recordsByRemoteID[$0] }
            )
            modelContext.insert(todo)
            todo.mailRecord?.todoItems.append(todo)
        }

        try modelContext.save()
    }

    private func uploadLocalData(for uid: String, modelContext: ModelContext) async throws {
        guard shouldUseCloudSync else { return }

        let records = ((try? modelContext.fetch(FetchDescriptor<MailRecord>())) ?? []).filter { $0.ownerID == uid }
        for record in records {
            if record.remoteID == nil {
                record.remoteID = UUID().uuidString
            }
            try await cloudSyncService.saveMailRecord(MailRecordDTO(record: record), ownerID: uid)
        }

        let todos = ((try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []).filter { $0.ownerID == uid }
        for todo in todos {
            if todo.remoteID == nil {
                todo.remoteID = UUID().uuidString
            }
            try await cloudSyncService.saveTodoItem(TodoItemDTO(todo: todo), ownerID: uid)
        }

        try modelContext.save()
    }

    private var shouldUseCloudSync: Bool {
        state.isAuthenticated
            && !CommandLine.arguments.contains("-uiTestingMockAuth")
            && !CommandLine.arguments.contains("-uiTestingExistingAuth")
    }

    private func shouldPromptForFaceIDUnlock(provider: AuthProvider) -> Bool {
        guard provider != .mock, !faceIDSettingsStore.isFaceIDUnlockEnabled else {
            return false
        }

        if CommandLine.arguments.contains("-uiTestingMockAuth") {
            return CommandLine.arguments.contains("-uiTestingPromptFaceID")
        }

        return true
    }

    private func setFaceIDUnlockEnabled(_ isEnabled: Bool) {
        faceIDSettingsStore.isFaceIDUnlockEnabled = isEnabled
        isFaceIDUnlockEnabled = isEnabled
    }

    private var cloudSyncOwnerID: String? {
        guard shouldUseCloudSync else { return nil }
        return ownerID
    }

    private func runCloudOperation(_ operation: @escaping () async throws -> Void) async {
        do {
            if let ownerID = cloudSyncOwnerID {
                try await prepareFirebaseAuthForCloud(uid: ownerID)
            }
            try await operation()
        } catch {
            authError = "同步失败，请稍后重试。"
        }
    }

    private func clearLocalCache(modelContext: ModelContext) {
        let records = (try? modelContext.fetch(FetchDescriptor<MailRecord>())) ?? []
        for record in records {
            modelContext.delete(record)
        }

        let todos = (try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []
        for todo in todos {
            modelContext.delete(todo)
        }

        try? modelContext.save()
    }

    private func deleteData(ownerID: String, modelContext: ModelContext) {
        let records = ((try? modelContext.fetch(FetchDescriptor<MailRecord>())) ?? []).filter { $0.ownerID == ownerID }
        for record in records {
            modelContext.delete(record)
        }

        let todos = ((try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []).filter { $0.ownerID == ownerID }
        for todo in todos {
            modelContext.delete(todo)
        }

        try? modelContext.save()
    }
}

private extension MailRecordDTO {
    var suggestedTodoDrafts: [TodoDraft] {
        suggestedTodoTitles.enumerated().map { index, title in
            TodoDraft(
                title: title,
                deadline: index < suggestedTodoDeadlines.count ? suggestedTodoDeadlines[index] : createdAt
            )
        }
    }
}

private extension UIApplication {
    var mailMindPresentationAnchor: ASPresentationAnchor? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    var mailMindRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: ASPresentationAnchor
    private let controller: ASAuthorizationController
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(
        presentationAnchor: ASPresentationAnchor,
        controller: ASAuthorizationController,
        completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    ) {
        self.presentationAnchor = presentationAnchor
        self.controller = controller
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(AuthSessionError.missingAppleIdentityToken))
            return
        }

        completion(.success(credential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion(.failure(error))
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostPresentedViewController
        }

        return self
    }
}
