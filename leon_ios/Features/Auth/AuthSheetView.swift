import SwiftUI
import UIKit

struct AuthSheetView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login
        case register

        var id: String { rawValue }

        var title: String {
            switch self {
            case .login: return L10n.text(L10n.Auth.login)
            case .register: return L10n.text(L10n.Auth.register)
            }
        }
    }

    private enum Phase: Equatable {
        case form
        case verifyPending(email: String)
        case forgotPassword
        case forgotPasswordSent(email: String)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ingredientStore: IngredientStore
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var preferenceStore: PreferenceStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var mode: Mode
    @State private var phase: Phase = .form
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isResending: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false
    @State private var resendCooldownRemaining: Int = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case email
        case password
        case passwordConfirmation
    }

    private let authService = AuthService(client: APIClient())
    private let ingredientService = IngredientService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())
    private let resendCooldownSeconds = 60

    init(initialMode: Mode = .login) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .form:
                    formPhaseContent
                case let .verifyPending(pendingEmail):
                    verifyPendingContent(email: pendingEmail)
                case .forgotPassword:
                    forgotPasswordContent
                case let .forgotPasswordSent(sentEmail):
                    forgotPasswordSentContent(email: sentEmail)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.55), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || isResending)
                    .accessibilityLabel(L10n.text(L10n.Common.close))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color.white)
    }

    // MARK: - Form Phase

    private var formPhaseContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroHeader
                    modeSwitcher
                    formFields
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)

            primaryActionBar
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .login ? L10n.Auth.loginTitle : L10n.Auth.registerTitle)
                .font(.title2.weight(.bold))

            Text(mode == .login ? L10n.Auth.loginSubtitle : L10n.Auth.registerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = item
                        statusMessage = nil
                        focusedField = nil
                    }
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(mode == item ? Color.white : Color.primary)
                        .background {
                            if mode == item {
                                Capsule()
                                    .fill(AppTheme.accent)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
    }

    private var formFields: some View {
        VStack(spacing: 14) {
            if mode == .register {
                labeledField(
                    title: L10n.text(L10n.Auth.name),
                    prompt: L10n.text(L10n.Auth.namePrompt),
                    field: .name
                ) {
                    TextField(L10n.Auth.namePrompt, text: $name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                }
            }

            labeledField(
                title: L10n.text(L10n.Auth.email),
                prompt: L10n.text(L10n.Auth.emailPrompt),
                field: .email
            ) {
                TextField(L10n.Auth.emailPrompt, text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
            }

            labeledField(
                title: L10n.text(L10n.Auth.password),
                prompt: L10n.text(mode == .register ? L10n.Auth.passwordPromptRegister : L10n.Auth.passwordPrompt),
                field: .password
            ) {
                SecureField(
                    mode == .register ? L10n.Auth.passwordPromptRegister : L10n.Auth.passwordPrompt,
                    text: $password
                )
                    .textContentType(mode == .login ? .password : .newPassword)
                    .focused($focusedField, equals: .password)
            }

            if mode == .login {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .forgotPassword
                            statusMessage = nil
                            statusIsError = false
                            focusedField = nil
                        }
                    } label: {
                        Text(L10n.Auth.forgotPassword)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }

            if mode == .register {
                labeledField(
                    title: L10n.text(L10n.Auth.passwordConfirm),
                    prompt: L10n.text(L10n.Auth.passwordConfirmPrompt),
                    field: .passwordConfirmation
                ) {
                    SecureField(L10n.Auth.passwordConfirmPrompt, text: $passwordConfirmation)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .passwordConfirmation)
                }
            }
        }
    }

    private func labeledField<Content: View>(
        title: String,
        prompt: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            focusedField == field ? AppTheme.accent.opacity(0.7) : Color.black.opacity(0.08),
                            lineWidth: focusedField == field ? 1.5 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(prompt)
    }

    private var primaryActionBar: some View {
        VStack(spacing: 12) {
            if let statusMessage {
                statusBanner(statusMessage, isError: statusIsError)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                handlePrimaryTap()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(mode == .login ? L10n.Auth.loginAction : L10n.Auth.registerAction)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    AppTheme.accent,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: AppTheme.accent.opacity(0.28), radius: 10, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isSubmitting)
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = mode == .login ? .register : .login
                    statusMessage = nil
                    focusedField = nil
                }
            } label: {
                Text(mode == .login ? L10n.Auth.goRegister : L10n.Auth.goLogin)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .disabled(isSubmitting)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.clear)
        .overlay(alignment: .top) {
            Divider().opacity(0.2)
        }
        .animation(.easeInOut(duration: 0.2), value: statusMessage)
    }

    // MARK: - Verify Pending Phase

    private func verifyPendingContent(email pendingEmail: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    phaseHeader(
                        icon: "envelope.open.fill",
                        title: L10n.text(L10n.Auth.verifyTitle),
                        subtitle: L10n.Auth.verifySubtitle(email: pendingEmail)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        stepRow(number: "1", text: L10n.text(L10n.Auth.verifyStep1))
                        stepRow(number: "2", text: L10n.text(L10n.Auth.verifyStep2))
                        stepRow(number: "3", text: L10n.text(L10n.Auth.verifyStep3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }

            VStack(spacing: 12) {
                if let statusMessage {
                    statusBanner(statusMessage, isError: statusIsError)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .form
                        mode = .login
                        email = pendingEmail
                        password = ""
                        statusMessage = nil
                    }
                } label: {
                    Text(L10n.Auth.verifyGoLogin)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await resendVerification(to: pendingEmail) }
                } label: {
                    HStack(spacing: 8) {
                        if isResending {
                            ProgressView()
                        }
                        Text(resendButtonTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(canResend ? AppTheme.accent : Color.secondary)
                    .contentShape(Rectangle())
                }
                .disabled(!canResend)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.clear)
            .overlay(alignment: .top) { Divider().opacity(0.35) }
            .animation(.easeInOut(duration: 0.2), value: statusMessage)
        }
    }

    // MARK: - Forgot Password

    private var forgotPasswordContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    phaseHeader(
                        icon: "key.fill",
                        title: L10n.text(L10n.Auth.resetTitle),
                        subtitle: L10n.text(L10n.Auth.resetSubtitle)
                    )

                    labeledField(
                        title: L10n.text(L10n.Auth.email),
                        prompt: L10n.text(L10n.Auth.emailPrompt),
                        field: .email
                    ) {
                        TextField(L10n.Auth.emailPrompt, text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 12) {
                if let statusMessage {
                    statusBanner(statusMessage, isError: statusIsError)
                }

                Button {
                    focusedField = nil
                    Task { await submitForgotPassword() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(L10n.Auth.resetSend)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(
                        canRequestPasswordReset && !isSubmitting ? AppTheme.accent : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!canRequestPasswordReset || isSubmitting)
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .form
                        mode = .login
                        statusMessage = nil
                        focusedField = nil
                    }
                } label: {
                    Text(L10n.Auth.resetBackLogin)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .disabled(isSubmitting)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.clear)
            .overlay(alignment: .top) { Divider().opacity(0.35) }
            .animation(.easeInOut(duration: 0.2), value: statusMessage)
        }
    }

    private func forgotPasswordSentContent(email sentEmail: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    phaseHeader(
                        icon: "envelope.badge.shield.half.filled",
                        title: L10n.text(L10n.Auth.resetSentTitle),
                        subtitle: L10n.Auth.resetSentSubtitle(email: sentEmail)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        stepRow(number: "1", text: L10n.text(L10n.Auth.resetStep1))
                        stepRow(number: "2", text: L10n.text(L10n.Auth.resetStep2))
                        stepRow(number: "3", text: L10n.text(L10n.Auth.resetStep3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }

            VStack(spacing: 12) {
                if let statusMessage {
                    statusBanner(statusMessage, isError: statusIsError)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .form
                        mode = .login
                        email = sentEmail
                        password = ""
                        statusMessage = nil
                    }
                } label: {
                    Text(L10n.Auth.resetBackLogin)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await submitForgotPassword(resendTo: sentEmail) }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                        }
                        Text(forgotResendButtonTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(canResendForgot ? AppTheme.accent : Color.secondary)
                    .contentShape(Rectangle())
                }
                .disabled(!canResendForgot)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.clear)
            .overlay(alignment: .top) { Divider().opacity(0.35) }
            .animation(.easeInOut(duration: 0.2), value: statusMessage)
        }
    }

    private func phaseHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text(title)
                .font(.title2.weight(.bold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppTheme.accent, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusBanner(_ message: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? AppTheme.danger : AppTheme.accent)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isError ? AppTheme.danger.opacity(0.12) : AppTheme.accent.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - State Helpers

    private var canRequestPasswordReset: Bool {
        isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canResendForgot: Bool {
        !isSubmitting && resendCooldownRemaining == 0
    }

    private var forgotResendButtonTitle: String {
        if resendCooldownRemaining > 0 {
            return L10n.Auth.resendCountdown(resendCooldownRemaining)
        }
        return L10n.text(L10n.Auth.resetResend)
    }

    private var canSubmit: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .login:
            return isValidEmail(trimmedEmail) && !password.isEmpty
        case .register:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && isValidEmail(trimmedEmail)
                && password.count >= 6
                && passwordConfirmation.count >= 6
        }
    }

    private var canResend: Bool {
        !isResending && resendCooldownRemaining == 0
    }

    private var resendButtonTitle: String {
        if resendCooldownRemaining > 0 {
            return L10n.Auth.resendCountdown(resendCooldownRemaining)
        }
        return L10n.text(L10n.Auth.verifyResend)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Actions

    private func handlePrimaryTap() {
        if canSubmit {
            Task { await submit() }
            return
        }
        focusedField = firstIncompleteField
    }

    private var firstIncompleteField: Field {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .login:
            if !isValidEmail(trimmedEmail) {
                return .email
            }
            return .password
        case .register:
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .name
            }
            if !isValidEmail(trimmedEmail) {
                return .email
            }
            if password.count < 6 {
                return .password
            }
            return .passwordConfirmation
        }
    }

    private func submit() async {
        isSubmitting = true
        statusMessage = nil
        statusIsError = false

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
                    syncNotes.append(L10n.Auth.syncIngredientsOK(syncResponse.data.syncedCount))
                } catch {
                    syncNotes.append(L10n.text(L10n.Auth.syncIngredientsFail))
                }
            } else {
                syncNotes.append(L10n.text(L10n.Auth.syncIngredientsEmpty))
            }

            do {
                let preferenceResponse = try await profileService.updatePreferences(tabOrder: preferenceStore.syncableTabOrder)
                preferenceStore.applyRemoteTabOrder(preferenceResponse.data.tabOrder)
                syncNotes.append(L10n.text(L10n.Auth.syncPreferenceOK))
            } catch {
                syncNotes.append(L10n.text(L10n.Auth.syncPreferenceFail))
            }

            await profileStore.refresh()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
            profileStore.markSyncMessage(syncNotes.joined(separator: "，"))
            dismiss()
        } catch {
            let apiError = error as? APIClientError
            let businessCode = apiError?.businessCode
            let message = error.localizedDescription

            if businessCode == APIBusinessCode.authEmailUnverified
                || message.contains("邮箱验证")
                || message.lowercased().contains("verify your email") {
                let pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .verifyPending(email: pendingEmail)
                    statusMessage = message
                    statusIsError = false
                }
            } else {
                statusMessage = message
                statusIsError = true
            }
        }
    }

    private func submitRegister() async {
        guard password == passwordConfirmation else {
            statusMessage = L10n.text(L10n.Auth.passwordMismatch)
            statusIsError = true
            return
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            _ = try await authService.register(
                name: name,
                email: trimmedEmail,
                password: password,
                passwordConfirmation: passwordConfirmation
            )

            password = ""
            passwordConfirmation = ""
            startResendCooldown()

            withAnimation(.easeInOut(duration: 0.25)) {
                phase = .verifyPending(email: trimmedEmail)
                statusMessage = L10n.text(L10n.Auth.verifyMailSent)
                statusIsError = false
            }
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func resendVerification(to pendingEmail: String) async {
        isResending = true
        statusMessage = nil
        statusIsError = false

        do {
            let response = try await authService.resendVerification(email: pendingEmail)
            startResendCooldown()
            statusMessage = response.message.isEmpty ? L10n.Auth.defaultVerificationResent() : response.message
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }

        isResending = false
    }

    private func submitForgotPassword(resendTo: String? = nil) async {
        let targetEmail = (resendTo ?? email).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(targetEmail) else {
            statusMessage = L10n.text(L10n.Auth.invalidEmail)
            statusIsError = true
            return
        }

        isSubmitting = true
        statusMessage = nil
        statusIsError = false

        do {
            let response = try await authService.forgotPassword(email: targetEmail)
            email = targetEmail
            startResendCooldown()
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = .forgotPasswordSent(email: targetEmail)
                statusMessage = response.message.isEmpty
                    ? L10n.Auth.defaultPasswordResetSent()
                    : response.message
                statusIsError = false
            }
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }

        isSubmitting = false
    }

    private func startResendCooldown() {
        resendCooldownRemaining = resendCooldownSeconds
        Task {
            while resendCooldownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if resendCooldownRemaining > 0 {
                        resendCooldownRemaining -= 1
                    }
                }
            }
        }
    }
}
