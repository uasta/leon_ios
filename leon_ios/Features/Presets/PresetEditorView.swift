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
        _defaultUnit = State(initialValue: preset?.defaultUnit ?? L10n.text(L10n.Action.unitPortion))
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
                    TextField(L10n.text(L10n.Action.name), text: $name)
                    TextField(L10n.text(L10n.Presets.unitPrompt), text: $defaultUnit)
                    Picker(L10n.text(L10n.Presets.defaultLocation), selection: $defaultLocation) {
                        ForEach(Ingredient.Location.allCases) { loc in
                            Label(loc.localizedTitle, systemImage: loc.systemImage)
                                .tag(loc)
                        }
                    }
                }

                Section(L10n.text(L10n.Presets.iconSection)) {
                    Picker(L10n.text(L10n.Presets.iconType), selection: $iconMode) {
                        Text(L10n.text(L10n.Presets.iconSystem)).tag(IconMode.system)
                        Text(L10n.text(L10n.Presets.iconAsset)).tag(IconMode.asset)
                    }

                    if iconMode == .system {
                        TextField(L10n.text(L10n.Presets.sfSymbol), text: $systemIconName)
                        HStack {
                            Text(L10n.text(L10n.Action.preview))
                            Spacer()
                            Image(systemName: systemIconName.isEmpty ? "questionmark" : systemIconName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField(L10n.text(L10n.Presets.assetName), text: $assetIconName)
                        HStack {
                            Text(L10n.text(L10n.Action.preview))
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

                Section(L10n.text(L10n.Presets.expirySection)) {
                    Toggle(L10n.text(L10n.Presets.useExpiryDays), isOn: $hasExpiryTemplate.animation(.default))
                    if hasExpiryTemplate {
                        Stepper(value: $expiryDays, in: 0...365) {
                            Text(L10n.Presets.defaultDays(expiryDays))
                        }
                    }
                }

                Section(L10n.text(L10n.Presets.defaultTags)) {
                    TextField(L10n.text(L10n.Ingredients.tagsPrompt), text: $tagsText)
                }
            }
            .navigationTitle(original == nil ? L10n.text(L10n.Presets.editorTitleNew) : L10n.text(L10n.Presets.editorTitleEdit))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text(L10n.Common.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(L10n.Action.save)) { saveAndDismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = defaultUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.text(L10n.Action.unitPortion) : defaultUnit
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

