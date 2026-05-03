import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MailMindTab = .upload
    @State private var todoListResetID = UUID()
    @State private var historyResetID = UUID()

    var body: some View {
        Group {
            if authSession.state.requiresLocalUnlock {
                FaceIDUnlockView()
            } else if authSession.isSignedInOrGuest {
                TabView(selection: $selectedTab) {
                    UploadView()
                        .tag(MailMindTab.upload)
                        .tabItem {
                            Label("上传", systemImage: "tray.and.arrow.up")
                        }

                    TodoListView()
                        .id(todoListResetID)
                        .tag(MailMindTab.todo)
                        .tabItem {
                            Label("待办", systemImage: "checklist")
                        }

                    HistoryView()
                        .id(historyResetID)
                        .tag(MailMindTab.history)
                        .tabItem {
                            Label("历史", systemImage: "clock")
                        }
                }
                .tint(MailMindTheme.primary)
                .onChange(of: selectedTab) { _, newTab in
                    switch newTab {
                    case .upload:
                        break
                    case .todo:
                        todoListResetID = UUID()
                    case .history:
                        historyResetID = UUID()
                    }
                }
            } else {
                LoginView()
            }
        }
        .task {
            await authSession.restoreSessionIfNeeded(modelContext: modelContext)
        }
        .alert("启用 Face ID 快速解锁？", isPresented: $authSession.shouldOfferFaceIDUnlock) {
            Button("暂不启用", role: .cancel) {
                authSession.skipFaceIDUnlockOffer()
            }
            Button("启用") {
                authSession.enableFaceIDUnlock()
            }
        } message: {
            Text("之后打开 MailMind 时，可以先用 Face ID 解锁已登录的本机账号。")
        }
        .alert("提示", isPresented: .constant(authSession.authError != nil)) {
            Button("知道了") {
                authSession.authError = nil
            }
        } message: {
            Text(authSession.authError ?? "")
        }
    }
}

private struct FaceIDUnlockView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext
    @State private var hasAttemptedAutomaticUnlock = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                Image(systemName: "faceid")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(MailMindTheme.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("使用 Face ID 解锁")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MailMindTheme.text)
                    Text("MailMind 已找到上次登录的账号。通过 Face ID 后即可继续同步和查看数据。")
                        .font(.title3)
                        .foregroundStyle(MailMindTheme.mutedText)
                        .lineSpacing(3)
                }

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await authSession.unlockWithFaceID(modelContext: modelContext)
                        }
                    } label: {
                        Label("使用 Face ID 解锁", systemImage: "faceid")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MailMindTheme.primary)
                    .accessibilityIdentifier("faceIDUnlockButton")

                    Button {
                        authSession.signInAgainFromLocalUnlock(modelContext: modelContext)
                    } label: {
                        Text("重新验证登陆")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(MailMindTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(MailMindTheme.text)
                    .accessibilityIdentifier("signInAgainButton")
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .background(MailMindTheme.background.ignoresSafeArea())
            .task {
                guard !hasAttemptedAutomaticUnlock else { return }
                hasAttemptedAutomaticUnlock = true
                await authSession.unlockWithFaceID(modelContext: modelContext)
            }
        }
    }
}

private enum MailMindTab: Hashable {
    case upload
    case todo
    case history
}

#Preview {
    ContentView()
        .environmentObject(AuthSession())
        .modelContainer(for: [MailRecord.self, TodoItem.self], inMemory: true)
}

private struct LoginView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(MailMindTheme.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("欢迎使用 MailMind")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MailMindTheme.text)
                    Text("登录后可同步邮件摘要和待办；也可以先用访客模式本机体验。")
                        .font(.title3)
                        .foregroundStyle(MailMindTheme.mutedText)
                        .lineSpacing(3)
                }

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await authSession.signInWithGoogle(modelContext: modelContext)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image("GoogleG")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            Text("使用 Google 登录")
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundStyle(MailMindTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(MailMindTheme.mutedText.opacity(0.28))
                    .accessibilityIdentifier("googleSignInButton")

                    Button {
                        Task {
                            await authSession.signInWithApple(modelContext: modelContext)
                        }
                    } label: {
                        Label("使用 Apple 登录", systemImage: "apple.logo")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .accessibilityIdentifier("appleSignInButton")

                    Button {
                        authSession.continueAsGuest()
                    } label: {
                        Text("访客模式")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MailMindTheme.primary)
                    .accessibilityIdentifier("guestModeButton")
                }

                Text("访客模式的数据只保存在本机，退出访客后会被清除。")
                    .font(.body)
                    .foregroundStyle(MailMindTheme.mutedText)

                Spacer(minLength: 0)
            }
            .padding(24)
            .background(MailMindTheme.background.ignoresSafeArea())
        }
    }
}
