//
//  MailMindApp.swift
//  MailMind
//
//  Created by Kaiqi Wang on 4/27/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct MailMindApp: App {
    @StateObject private var authSession = AuthSession()

    init() {
        FirebaseApp.configure()
        FirebaseBackendEnvironment.configureEmulatorsIfNeeded()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MailRecord.self,
            TodoItem.self,
        ])
        let isTesting = CommandLine.arguments.contains("-uiTestingResetStore")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        let modelConfiguration = ModelConfiguration(
            "MailMind_v2",
            schema: schema,
            isStoredInMemoryOnly: isTesting
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authSession)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
