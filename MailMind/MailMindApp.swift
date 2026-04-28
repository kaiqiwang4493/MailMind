//
//  MailMindApp.swift
//  MailMind
//
//  Created by Kaiqi Wang on 4/27/26.
//

import SwiftUI
import SwiftData

@main
struct MailMindApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MailRecord.self,
            TodoItem.self,
        ])
        let isUITesting = CommandLine.arguments.contains("-uiTestingResetStore")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
