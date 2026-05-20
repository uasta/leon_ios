import SwiftUI

struct AuthSheetView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login
        case register

        var id: String { rawValue }

        var title: String {
            switch self {
            case .login: return "登录"
            case .register: return "注册"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ingredientStore: IngredientStore
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var preferenceStore: PreferenceStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var mode: Mode
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""
    @State private var isSubmitting: Bool = false
    @State private var statusMessage: String?

    private let authService = AuthService(client: APIClient())
    private let ingredientService = IngredientService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())

    init(initialMode: Mode = .login) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("模式", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if mode == .register {
                        TextField("昵称", text: $name)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    SecureField("密码", text: $password)

                    if mode == .register {
                        SecureField("确认密码", text: $passwordConfirmation)
                    }
                } header: {
                    Text(mode == .login ? "账号登录" : "创建账号")
                } footer: {
                    Text(modeFooterText)
                }

                Section {
                    Label("同步本地食材到账号", systemImage: "arrow.triangle.2.circlepath")
                    Label("同步当前 Tab 顺序偏好", systemImage: "square.grid.3x1.folder.badge.plus")
                    Label("拉取我的点赞、收藏和历史", systemImage: "tray.full")
                } header: {
                    Text(mode == .login ? "登录后会发生什么" : "注册后下一步")
                } footer: {
                    if mode == .register {
                        Text("当前后端要求邮箱验证，注册成功后请先完成验证，再回来登录。")
                    }
                }

                if let statusMessage {
                    Section("状态") {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(mode == .login ? "登录" : "注册") {
                            Task {
                                await submit()
                            }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .login:
            return !trimmedEmail.isEmpty && !password.isEmpty
        case .register:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !trimmedEmail.isEmpty
                && password.count >= 6
                && passwordConfirmation.count >= 6
        }
    }

    private var modeFooterText: String {
        switch mode {
        case .login:
            return "登录后会自动同步本地食材和导航偏好。"
        case .register:
            return "注册后将发送验证邮件，完成验证后即可回来登录。"
        }
    }

    private func submit() async {
        isSubmitting = true
        statusMessage = nil

        switch mode {
        case .login:
            await submitLogin()
        case .register:
            await submitRegister()
        }

        isSubmitting = false
    }

    private func submitLogin() async {
        do {
            let loginResponse = try await authService.login(email: email, password: password)
            let loginData = loginResponse.data
            sessionStore.configureAuthenticatedSession(user: loginData.user, token: loginData.token)

            var syncNotes: [String] = []
            let drafts = ingredientStore.activeSyncDrafts()
            if !drafts.isEmpty {
                do {
                    let syncResponse = try await ingredientService.bootstrapLocalIngredients(drafts)
                    syncNotes.append("食材同步 \(syncResponse.data.syncedCount) 项")
                } catch {
                    syncNotes.append("食材同步失败")
                }
            } else {
                syncNotes.append("没有待同步食材")
            }

            do {
                let preferenceResponse = try await profileService.updatePreferences(tabOrder: preferenceStore.tabOrder)
                preferenceStore.applyRemoteTabOrder(preferenceResponse.data.tabOrder)
                syncNotes.append("偏好已同步")
            } catch {
                syncNotes.append("偏好同步失败")
            }

            await profileStore.refresh()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
            profileStore.markSyncMessage(syncNotes.joined(separator: "，"))
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func submitRegister() async {
        guard password == passwordConfirmation else {
            statusMessage = "两次输入的密码不一致"
            return
        }

        do {
            let response = try await authService.register(
                name: name,
                email: email,
                password: password,
                passwordConfirmation: passwordConfirmation
            )

            statusMessage = "已为 \(response.data.user.email) 创建账号，请先完成邮箱验证，再回来登录。"
            mode = .login
            password = ""
            passwordConfirmation = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
