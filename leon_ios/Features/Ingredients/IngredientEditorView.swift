import SwiftUI

struct IngredientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: IngredientStore
    @EnvironmentObject private var presetStore: IngredientPresetStore

    private let original: Ingredient?

    @State private var name: String
    @State private var quantity: Double
    @State private var unit: String
    @State private var location: Ingredient.Location
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var note: String
    @State private var tagsText: String
    @State private var showPresetManager: Bool = false

    init(ingredient: Ingredient?) {
        self.original = ingredient
        _name = State(initialValue: ingredient?.name ?? "")
        _quantity = State(initialValue: ingredient?.quantity ?? 1)
        _unit = State(initialValue: ingredient?.unit ?? L10n.text(L10n.Action.unitPortion))
        _location = State(initialValue: ingredient?.location ?? .fridgeChill)
        _hasExpiry = State(initialValue: ingredient?.expiryDate != nil)
        _expiryDate = State(initialValue: ingredient?.expiryDate ?? Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
        _note = State(initialValue: ingredient?.note ?? "")
        _tagsText = State(initialValue: ingredient?.tags.joined(separator: " ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(presetStore.presets) { preset in
                                Button {
                                    apply(preset)
                                } label: {
                                    HStack(spacing: 8) {
                                        presetIcon(preset)
                                            .frame(width: 20, height: 20)
                                        Text(preset.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                showPresetManager = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                    Text(L10n.text(L10n.Action.manage))
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(L10n.text(L10n.Ingredients.presetsHeader))
                } footer: {
                    Text(L10n.text(L10n.Ingredients.presetsFooter))
                }

                Section {
                    TextField(L10n.text(L10n.Action.name), text: $name)
                        .textInputAutocapitalization(.never)

                    HStack {
                        Text(L10n.text(L10n.Action.quantity))
                        Spacer()
                        TextField("1", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }

                    TextField(L10n.text(L10n.Ingredients.unitPrompt), text: $unit)

                    Picker(L10n.text(L10n.Action.location), selection: $location) {
                        ForEach(Ingredient.Location.allCases) { loc in
                            Label(loc.localizedTitle, systemImage: loc.systemImage)
                                .tag(loc)
                        }
                    }
                }

                Section(L10n.text(L10n.Ingredients.expirySection)) {
                    Toggle(L10n.text(L10n.Ingredients.setExpiry), isOn: $hasExpiry.animation(.default))
                    if hasExpiry {
                        DatePicker(L10n.text(L10n.Ingredients.expiryDate), selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section(L10n.text(L10n.Action.tags)) {
                    TextField(L10n.text(L10n.Ingredients.tagsPrompt), text: $tagsText)
                }

                Section(L10n.text(L10n.Action.note)) {
                    TextField(L10n.text(L10n.Action.optional), text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(original == nil ? L10n.text(L10n.Ingredients.editorTitleNew) : L10n.text(L10n.Ingredients.editorTitleEdit))
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
            .sheet(isPresented: $showPresetManager) {
                PresetManagerView()
                    .environmentObject(presetStore)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func saveAndDismiss() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsText
            .split(whereSeparator: \.isWhitespace)
            .map { String($0) }
            .filter { !$0.isEmpty }

        let updated = Ingredient(
            id: original?.id ?? UUID(),
            name: cleanedName,
            quantity: quantity <= 0 ? nil : quantity,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.text(L10n.Action.unitPortion) : unit,
            location: location,
            purchaseDate: original?.purchaseDate,
            expiryDate: hasExpiry ? expiryDate : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            isArchived: original?.isArchived ?? false
        )

        if original == nil {
            store.add(updated)
        } else {
            store.update(updated)
        }
        dismiss()
    }

    private func apply(_ preset: IngredientPreset) {
        name = preset.name
        unit = preset.defaultUnit
        location = preset.defaultLocation

        let currentTags = tagsText
            .split(whereSeparator: \.isWhitespace)
            .map { String($0) }
        let merged = Array(Set(currentTags + preset.tags))
            .sorted()
        tagsText = merged.joined(separator: " ")

        if let days = preset.defaultExpiryDays {
            hasExpiry = true
            expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? expiryDate
        }
    }

    @ViewBuilder
    private func presetIcon(_ preset: IngredientPreset) -> some View {
        switch preset.icon {
        case .system(let name):
            Image(systemName: name)
                .foregroundStyle(.secondary)
        case .asset(let name):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            } else {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

#Preview {
    IngredientEditorView(ingredient: nil)
        .environmentObject(IngredientStore())
        .environmentObject(IngredientPresetStore())
}

