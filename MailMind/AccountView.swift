import SwiftData
import SwiftUI

struct AccountToolbarButton: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingAccount = false

    var body: some View {
        Button {
            isShowingAccount = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("账号")
        .sheet(isPresented: $isShowingAccount) {
            AccountView(exitGuest: {
                isShowingAccount = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    authSession.exitGuestFromPresentedUI(modelContext: modelContext)
                }
            }, signOut: {
                isShowingAccount = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    authSession.signOutFromPresentedUI(modelContext: modelContext)
                }
            })
                .environmentObject(authSession)
        }
        .onChange(of: authSession.state) { _, newState in
            if case .signedOut = newState {
                isShowingAccount = false
            }
        }
    }
}

private struct AccountView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingGuestExit = false
    let exitGuest: () -> Void
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("当前身份") {
                    HStack {
                        Label(authSession.state.displayName, systemImage: authSession.state.isGuest ? "person" : "person.crop.circle.badge.checkmark")
                        Spacer()
                        if authSession.state.isGuest {
                            Text("本机保存")
                                .foregroundStyle(MailMindTheme.mutedText)
                        } else {
                            Text("云端同步")
                                .foregroundStyle(MailMindTheme.primary)
                        }
                    }
                }

                if authSession.state.isGuest {
                    Section {
                        Button {
                            Task {
                                await authSession.signInWithApple(modelContext: modelContext)
                                if authSession.state.isAuthenticated {
                                    dismiss()
                                }
                            }
                        } label: {
                            Label("使用 Apple 登录并同步访客数据", systemImage: "apple.logo")
                        }

                        Button {
                            Task {
                                await authSession.signInWithGoogle(modelContext: modelContext)
                                if authSession.state.isAuthenticated {
                                    dismiss()
                                }
                            }
                        } label: {
                            Label("使用 Google 登录并同步访客数据", systemImage: "g.circle")
                        }
                    } footer: {
                        Text("登录成功后，当前访客模式下的历史记录和待办会自动迁移到账号。")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if authSession.state.isGuest {
                            isConfirmingGuestExit = true
                        } else {
                            signOut()
                        }
                    } label: {
                        Text(authSession.state.isGuest ? "退出访客并清除数据" : "退出登录")
                    }
                }
            }
            .navigationTitle("账号")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("清除访客数据？", isPresented: $isConfirmingGuestExit) {
                Button("取消", role: .cancel) {}
                Button("清除并退出", role: .destructive) {
                    exitGuest()
                }
            } message: {
                Text("退出后，访客模式下产生的历史记录和待办都会被删除。")
            }
            .alert("登录失败", isPresented: .constant(authSession.authError != nil)) {
                Button("知道了") {
                    authSession.authError = nil
                }
            } message: {
                Text(authSession.authError ?? "")
            }
        }
    }
}
