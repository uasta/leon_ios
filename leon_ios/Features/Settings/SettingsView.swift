import SwiftUI

struct SettingsView: View {
    @State private var showLoginSheet: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLoginSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("登录以开启同步")
                                    .font(.headline)
                                Text("换手机也不丢数据，未来可支持家庭共享。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("提醒") {
                    LabeledContent("临期提前", value: "2 天（占位）")
                    LabeledContent("提醒时段", value: "09:00（占位）")
                }

                Section("数据") {
                    Button("导出/备份（占位）") {}
                    Button("导入（占位）") {}
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .sheet(isPresented: $showLoginSheet) {
                LoginPlaceholderView()
            }
        }
    }
}

private struct LoginPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // TODO: 接微信授权登录
                    } label: {
                        Label("微信授权登录（占位）", systemImage: "message.fill")
                    }
                    Button {
                        // TODO: 接手机号验证码登录
                    } label: {
                        Label("手机号登录/注册（占位）", systemImage: "phone.fill")
                    }
                } footer: {
                    Text("建议先不强制登录：你可以先用本地模式体验，只有在需要同步/换机/共享时再登录。")
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

