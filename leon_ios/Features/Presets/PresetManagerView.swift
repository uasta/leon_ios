import SwiftUI

struct PresetManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var presetStore: IngredientPresetStore

    @State private var showEditor: Bool = false
    @State private var editingPreset: IngredientPreset? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(presetStore.presets) { preset in
                    Button {
                        editingPreset = preset
                        showEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            presetIcon(preset)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.headline)
                                Text("\(preset.defaultLocation.rawValue) · \(preset.defaultUnit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .onMove(perform: presetStore.move)
                .onDelete { indexSet in
                    for idx in indexSet {
                        let id = presetStore.presets[idx].id
                        presetStore.delete(id)
                    }
                }
            }
            .navigationTitle("管理预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingPreset = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增预设")
                }
            }
            .sheet(isPresented: $showEditor) {
                PresetEditorView(preset: editingPreset)
            }
        }
    }

    @ViewBuilder
    private func presetIcon(_ preset: IngredientPreset) -> some View {
        switch preset.icon {
        case .system(let name):
            Image(systemName: name)
        case .asset(let name):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "photo")
            } else {
                Image(name)
                    .renderingMode(.original)
            }
        }
    }
}

#Preview {
    PresetManagerView()
        .environmentObject(IngredientPresetStore())
}

