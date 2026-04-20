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
        _unit = State(initialValue: ingredient?.unit ?? "份")
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
                                    Text("管理")
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
                    Text("常用")
                } footer: {
                    Text("点选预设可快速填充名称/单位/位置，并可带默认到期天数与标签。")
                }

                Section {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.never)

                    HStack {
                        Text("数量")
                        Spacer()
                        TextField("1", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }

                    TextField("单位（如：个/份/kg）", text: $unit)

                    Picker("位置", selection: $location) {
                        ForEach(Ingredient.Location.allCases) { loc in
                            Label(loc.rawValue, systemImage: loc.systemImage)
                                .tag(loc)
                        }
                    }
                }

                Section("到期提醒") {
                    Toggle("设置到期日", isOn: $hasExpiry.animation(.default))
                    if hasExpiry {
                        DatePicker("到期日", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("标签") {
                    TextField("用空格分隔（如：蔬菜 肉类）", text: $tagsText)
                }

                Section("备注") {
                    TextField("可选", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(original == nil ? "新增食材" : "编辑食材")
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
            .sheet(isPresented: $showPresetManager) {
                PresetManagerView()
                    .environmentObject(presetStore)
            }
        }
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
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "份" : unit,
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

