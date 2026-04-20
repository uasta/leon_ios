import SwiftUI

struct IngredientsListView: View {
    @EnvironmentObject private var store: IngredientStore
    @Environment(\.editMode) private var editMode

    @State private var query: String = ""
    @State private var showEditor: Bool = false
    @State private var editingIngredient: Ingredient? = nil
    @State private var showArchived: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var selectedIDs: Set<Ingredient.ID> = []

    @State private var selectedLocations: Set<Ingredient.Location> = []
    @State private var selectedStatuses: Set<IngredientStatusFilter> = []
    @State private var selectedTags: Set<String> = []

    private var visibleItems: [Ingredient] {
        store.items
            .filter { showArchived ? true : !$0.isArchived }
            .filter { matchesFilter($0) }
            .filter {
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
                return $0.name.localizedCaseInsensitiveContains(query)
                    || $0.tags.joined(separator: " ").localizedCaseInsensitiveContains(query)
                    || $0.location.rawValue.localizedCaseInsensitiveContains(query)
            }
    }

    private var grouped: [(title: String, items: [Ingredient])] {
        let expiring = visibleItems.filter {
            if case .expiringSoon = $0.freshness { return true }
            return false
        }
        let expired = visibleItems.filter { $0.freshness == .expired }
        let fresh = visibleItems.filter { $0.freshness == .fresh }
        let noExpiry = visibleItems.filter { $0.freshness == .noExpiry }

        var result: [(String, [Ingredient])] = []
        if !expiring.isEmpty { result.append(("临期", expiring)) }
        if !fresh.isEmpty { result.append(("新鲜", fresh)) }
        if !noExpiry.isEmpty { result.append(("无到期日", noExpiry)) }
        if !expired.isEmpty { result.append(("已过期", expired)) }
        return result
    }

    private var allTags: [String] {
        let tags = store.items.flatMap(\.tags)
        return Array(Set(tags)).sorted()
    }

    private var isSelecting: Bool {
        editMode?.wrappedValue == .active
    }

    private var hasActiveFilter: Bool {
        !selectedLocations.isEmpty || !selectedStatuses.isEmpty || !selectedTags.isEmpty || showArchived
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        "还没有食材",
                        systemImage: "carrot",
                        description: Text("先添加几个常用食材，临期提醒会更有用。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedIDs) {
                        ForEach(grouped, id: \.title) { section in
                            Section(section.title) {
                                ForEach(section.items) { item in
                                    row(item)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("我的食材")
            .navigationDestination(for: Ingredient.self) { ingredient in
                IngredientDetailView(ingredientID: ingredient.id)
            }
            .searchable(text: $query, prompt: "搜索名称/标签/位置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选")
                }
            }
            .toolbar {
                if isSelecting && !selectedIDs.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            selectedIDs.forEach { store.archive($0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label("用掉", systemImage: "checkmark.circle")
                        }

                        Spacer()

                        Button {
                            selectedIDs.forEach { store.postponeExpiry($0, days: 1) }
                        } label: {
                            Label("延期1天", systemImage: "calendar.badge.plus")
                        }

                        Spacer()

                        Button(role: .destructive) {
                            selectedIDs.forEach { store.delete($0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isSelecting {
                    addFloatingButton
                }
            }
            .sheet(isPresented: $showEditor) {
                IngredientEditorView(ingredient: editingIngredient)
            }
            .sheet(isPresented: $showFilterSheet) {
                IngredientFilterSheet(
                    showArchived: $showArchived,
                    selectedLocations: $selectedLocations,
                    selectedStatuses: $selectedStatuses,
                    selectedTags: $selectedTags,
                    allTags: allTags
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: isSelecting) { _, newValue in
                if !newValue { selectedIDs.removeAll() }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Ingredient) -> some View {
        if isSelecting {
            IngredientRow(item: item)
                .tag(item.id)
        } else {
            NavigationLink(value: item) {
                IngredientRow(item: item)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    store.archive(item.id)
                } label: {
                    Label("用掉", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)

                Button(role: .destructive) {
                    store.delete(item.id)
                } label: {
                    Label("丢弃", systemImage: "trash.fill")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    store.postponeExpiry(item.id, days: 1)
                } label: {
                    Label("延期 1 天", systemImage: "calendar.badge.plus")
                }
                .tint(.blue)

                Button {
                    editingIngredient = item
                    showEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(.gray)
            }
        }
    }

    private var addFloatingButton: some View {
        Button {
            editingIngredient = nil
            showEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.tint, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .padding(.trailing, 18)
        .padding(.bottom, 18)
        .accessibilityLabel("新增食材")
    }

    private func matchesFilter(_ item: Ingredient) -> Bool {
        if !selectedLocations.isEmpty, !selectedLocations.contains(item.location) {
            return false
        }

        if !selectedTags.isEmpty {
            let hasAnyTag = !Set(item.tags).intersection(selectedTags).isEmpty
            if !hasAnyTag { return false }
        }

        if !selectedStatuses.isEmpty {
            let status = IngredientStatusFilter(from: item.freshness)
            if let status, !selectedStatuses.contains(status) { return false }
            if status == nil { return false }
        }

        return true
    }
}

private struct IngredientRow: View {
    let item: Ingredient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.location.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(item.location.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    freshnessPill
                }
            }

            Spacer(minLength: 12)

            Text(item.quantityText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var freshnessPill: some View {
        switch item.freshness {
        case .expired:
            Label("过期", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleOnly)
                .font(.caption)
                .foregroundStyle(.red)
        case .expiringSoon(let daysLeft):
            Text(daysLeft == 0 ? "今天到期" : "剩 \(daysLeft) 天")
                .font(.caption)
                .foregroundStyle(.orange)
        case .fresh:
            Text("新鲜")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .noExpiry:
            Text("不提醒")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    IngredientsListView()
        .environmentObject(IngredientStore())
        .environmentObject(IngredientPresetStore())
}

private enum IngredientStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case expiringSoon = "临期"
    case fresh = "新鲜"
    case noExpiry = "无到期日"
    case expired = "已过期"

    var id: String { rawValue }

    init?(from freshness: Ingredient.Freshness) {
        switch freshness {
        case .expired:
            self = .expired
        case .expiringSoon:
            self = .expiringSoon
        case .fresh:
            self = .fresh
        case .noExpiry:
            self = .noExpiry
        }
    }
}

private struct IngredientFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var showArchived: Bool
    @Binding var selectedLocations: Set<Ingredient.Location>
    @Binding var selectedStatuses: Set<IngredientStatusFilter>
    @Binding var selectedTags: Set<String>

    let allTags: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("显示已归档", isOn: $showArchived)
                }

                Section("位置") {
                    ForEach(Ingredient.Location.allCases) { loc in
                        Toggle(isOn: binding(for: loc)) {
                            Label(loc.rawValue, systemImage: loc.systemImage)
                        }
                    }
                }

                Section("状态") {
                    ForEach(IngredientStatusFilter.allCases) { status in
                        Toggle(isOn: binding(for: status)) {
                            Text(status.rawValue)
                        }
                    }
                }

                Section("标签") {
                    if allTags.isEmpty {
                        Text("暂无标签")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allTags, id: \.self) { tag in
                            Toggle(isOn: binding(forTag: tag)) {
                                Text(tag)
                            }
                        }
                    }
                }

                Section {
                    Button("清除筛选") {
                        selectedLocations.removeAll()
                        selectedStatuses.removeAll()
                        selectedTags.removeAll()
                        showArchived = false
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func binding(for location: Ingredient.Location) -> Binding<Bool> {
        Binding(
            get: { selectedLocations.contains(location) },
            set: { isOn in
                if isOn { selectedLocations.insert(location) }
                else { selectedLocations.remove(location) }
            }
        )
    }

    private func binding(for status: IngredientStatusFilter) -> Binding<Bool> {
        Binding(
            get: { selectedStatuses.contains(status) },
            set: { isOn in
                if isOn { selectedStatuses.insert(status) }
                else { selectedStatuses.remove(status) }
            }
        )
    }

    private func binding(forTag tag: String) -> Binding<Bool> {
        Binding(
            get: { selectedTags.contains(tag) },
            set: { isOn in
                if isOn { selectedTags.insert(tag) }
                else { selectedTags.remove(tag) }
            }
        )
    }
}

