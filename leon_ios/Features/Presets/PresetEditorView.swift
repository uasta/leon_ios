import SwiftUI

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var presetStore: IngredientPresetStore

    private let original: IngredientPreset?

    @State private var name: String
    @State private var defaultUnit: String
    @State private var defaultLocation: Ingredient.Location
    @State private var iconMode: IconMode
    @State private var systemIconName: String
    @State private var assetIconName: String
    @State private var hasExpiryTemplate: Bool
    @State private var expiryDays: Int
    @State private var tagsText: String

    init(preset: IngredientPreset?) {
        self.original = preset
        _name = State(initialValue: preset?.name ?? "")
        _defaultUnit = State(initialValue: preset?.defaultUnit ?? "份")
        _defaultLocation = State(initialValue: preset?.defaultLocation ?? .fridgeChill)

        switch preset?.icon {
        case .asset(let name):
            _iconMode = State(initialValue: .asset)
            _systemIconName = State(initialValue: "carrot")
            _assetIconName = State(initialValue: name)
        case .system(let name):
            _iconMode = State(initialValue: .system)
            _systemIconName = State(initialValue: name)
            _assetIconName = State(initialValue: "")
        case .none:
            _iconMode = State(initialValue: .system)
            _systemIconName = State(initialValue: "carrot")
            _assetIconName = State(initialValue: "")
        }

        _hasExpiryTemplate = State(initialValue: preset?.defaultExpiryDays != nil)
        _expiryDays = State(initialValue: preset?.defaultExpiryDays ?? 3)
        _tagsText = State(initialValue: preset?.tags.joined(separator: " ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $name)
                    TextField("默认单位（如：个/枚/kg）", text: $defaultUnit)
                    Picker("默认位置", selection: $defaultLocation) {
                        ForEach(Ingredient.Location.allCases) { loc in
                            Label(loc.rawValue, systemImage: loc.systemImage)
                                .tag(loc)
                        }
                    }
                }

                Section("图标") {
                    Picker("类型", selection: $iconMode) {
                        Text("系统图标").tag(IconMode.system)
                        Text("图片资源").tag(IconMode.asset)
                    }

                    if iconMode == .system {
                        TextField("SF Symbol 名称", text: $systemIconName)
                        HStack {
                            Text("预览")
                            Spacer()
                            Image(systemName: systemIconName.isEmpty ? "questionmark" : systemIconName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Assets 名称", text: $assetIconName)
                        HStack {
                            Text("预览")
                            Spacer()
                            if assetIconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(assetIconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                    }
                }

                Section("到期模板") {
                    Toggle("使用默认到期天数", isOn: $hasExpiryTemplate.animation(.default))
                    if hasExpiryTemplate {
                        Stepper(value: $expiryDays, in: 0...365) {
                            Text("默认 \(expiryDays) 天")
                        }
                    }
                }

                Section("默认标签") {
                    TextField("用空格分隔（如：蔬菜 肉类）", text: $tagsText)
                }
            }
            .navigationTitle(original == nil ? "新增预设" : "编辑预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAndDismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = defaultUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "份" : defaultUnit
        let tags = tagsText
            .split(whereSeparator: \.isWhitespace)
            .map { String($0) }
            .filter { !$0.isEmpty }

        let icon: IngredientPreset.Icon = {
            switch iconMode {
            case .system:
                let sym = systemIconName.trimmingCharacters(in: .whitespacesAndNewlines)
                return .system(name: sym.isEmpty ? "carrot" : sym)
            case .asset:
                let asset = assetIconName.trimmingCharacters(in: .whitespacesAndNewlines)
                return .asset(name: asset)
            }
        }()

        let preset = IngredientPreset(
            id: original?.id ?? UUID(),
            name: cleanedName,
            defaultUnit: unit,
            defaultLocation: defaultLocation,
            icon: icon,
            defaultExpiryDays: hasExpiryTemplate ? expiryDays : nil,
            tags: tags
        )

        if original == nil { presetStore.add(preset) }
        else { presetStore.update(preset) }

        dismiss()
    }
}

private enum IconMode: String, CaseIterable, Identifiable {
    case system
    case asset
    var id: String { rawValue }
}

#Preview {
    PresetEditorView(preset: nil)
        .environmentObject(IngredientPresetStore())
}

