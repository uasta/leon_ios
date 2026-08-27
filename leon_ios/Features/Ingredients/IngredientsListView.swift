import SwiftUI

struct IngredientsListView: View {
    @EnvironmentObject private var store: IngredientStore
    @EnvironmentObject private var presetStore: IngredientPresetStore
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var navigationStore: AppNavigationStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.editMode) private var editMode

    @State private var query: String = ""
    @State private var showEditor: Bool = false
    @State private var showOCRImport: Bool = false
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
                    || $0.location.localizedTitle.localizedCaseInsensitiveContains(query)
            }
    }

    private var grouped: [(kind: IngredientGroupKind, items: [Ingredient])] {
        let expiring = visibleItems.filter {
            if case .expiringSoon = $0.freshness { return true }
            return false
        }
        let expired = visibleItems.filter { $0.freshness == .expired }
        let fresh = visibleItems.filter { $0.freshness == .fresh }
        let noExpiry = visibleItems.filter { $0.freshness == .noExpiry }

        var result: [(IngredientGroupKind, [Ingredient])] = []
        if !expiring.isEmpty { result.append((.expiring, expiring)) }
        if !fresh.isEmpty { result.append((.fresh, fresh)) }
        if !noExpiry.isEmpty { result.append((.noExpiry, noExpiry)) }
        if !expired.isEmpty { result.append((.expired, expired)) }
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
                    emptyState
                } else {
                    ingredientList
                }
            }
            .appScreenBackground()
            .navigationTitle(L10n.text(L10n.Ingredients.listTitle))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Ingredient.self) { ingredient in
                IngredientDetailView(ingredientID: ingredient.id)
            }
            .searchable(text: $query, prompt: L10n.text(L10n.Ingredients.searchPrompt))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editingIngredient = nil
                            showEditor = true
                        } label: {
                            Label(L10n.text(L10n.OCR.entryManual), systemImage: "square.and.pencil")
                        }

                        Button {
                            showOCRImport = true
                        } label: {
                            Label(L10n.text(L10n.OCR.entryReceipt), systemImage: "doc.viewfinder")
                        }
                    } label: {
                        Text(L10n.text(L10n.Action.add))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(L10n.text(L10n.Action.filter))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .toolbar {
                if isSelecting && !selectedIDs.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            selectedIDs.forEach { store.archive($0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label(L10n.text(L10n.Action.markUsed), systemImage: "checkmark.circle")
                        }

                        Spacer()

                        Button {
                            selectedIDs.forEach { store.postponeExpiry($0, days: 1) }
                        } label: {
                            Label(L10n.text(L10n.Ingredients.postpone1d), systemImage: "calendar.badge.plus")
                        }

                        Spacer()

                        Button {
                            let selectedNames = store.items
                                .filter { selectedIDs.contains($0.id) }
                                .map(\.name)
                            recommendationStore.setSelectedIngredientNames(selectedNames)
                            navigationStore.switchToRecommend()
                            editMode?.wrappedValue = .inactive
                            selectedIDs.removeAll()
                        } label: {
                            Label(L10n.text(L10n.Ingredients.goRecommend), systemImage: "arrow.right.circle")
                        }

                        Spacer()

                        Button(role: .destructive) {
                            selectedIDs.forEach { store.delete($0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label(L10n.text(L10n.Action.delete), systemImage: "trash")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isSelecting && !visibleItems.isEmpty {
                    HStack {
                        Spacer()
                        addMenu {
                            AppFloatingActionButtonLabel()
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
                }
            }
            .sheet(isPresented: $showEditor) {
                IngredientEditorView(ingredient: editingIngredient)
                    .environmentObject(store)
                    .environmentObject(presetStore)
            }
            .sheet(isPresented: $showOCRImport) {
                ReceiptOCRImportView()
                    .environmentObject(store)
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
                .presentationDragIndicator(.visible)
            }
            .onChange(of: isSelecting) { _, newValue in
                if !newValue { selectedIDs.removeAll() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            AppListSubtitle(text: L10n.text(L10n.Ingredients.listSubtitle))
            ContentUnavailableView(
                L10n.text(L10n.Ingredients.emptyTitle),
                systemImage: "carrot",
                description: Text(L10n.text(L10n.Ingredients.emptySubtitle))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Button {
                    editingIngredient = nil
                    showEditor = true
                } label: {
                    Text(L10n.text(L10n.OCR.entryManual))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showOCRImport = true
                } label: {
                    Text(L10n.text(L10n.OCR.entryReceipt))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func addMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            Button {
                editingIngredient = nil
                showEditor = true
            } label: {
                Label(L10n.text(L10n.OCR.entryManual), systemImage: "square.and.pencil")
            }

            Button {
                showOCRImport = true
            } label: {
                Label(L10n.text(L10n.OCR.entryReceipt), systemImage: "doc.viewfinder")
            }
        } label: {
            label()
        }
    }

    private var ingredientList: some View {
        VStack(spacing: 0) {
            AppListSubtitle(text: L10n.text(L10n.Ingredients.listSubtitle))

            Group {
                if isSelecting {
                    List(selection: $selectedIDs) {
                        ingredientSections(selectionEnabled: true)
                    }
                } else {
                    List {
                        ingredientSections(selectionEnabled: false)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func ingredientSections(selectionEnabled: Bool) -> some View {
        ForEach(grouped, id: \.kind) { section in
            Section {
                ForEach(section.items) { item in
                    row(item, selectionEnabled: selectionEnabled)
                        .listRowBackground(
                            AppTheme.sectionBackground(for: section.kind.themeKind, scheme: colorScheme)
                        )
                }
            } header: {
                Text(section.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.sectionLabelColor(for: section.kind.themeKind))
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Ingredient, selectionEnabled: Bool) -> some View {
        if selectionEnabled {
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
                    Label(L10n.text(L10n.Action.markUsed), systemImage: "checkmark.circle.fill")
                }
                .tint(.green)

                Button(role: .destructive) {
                    store.delete(item.id)
                } label: {
                    Label(L10n.text(L10n.Ingredients.discard), systemImage: "trash.fill")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    store.postponeExpiry(item.id, days: 1)
                } label: {
                    Label(L10n.text(L10n.Ingredients.postpone1d), systemImage: "calendar.badge.plus")
                }
                .tint(AppTheme.accent)

                Button {
                    editingIngredient = item
                    showEditor = true
                } label: {
                    Label(L10n.text(L10n.Action.edit), systemImage: "pencil")
                }
                .tint(.gray)
            }
        }
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
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 36, height: 36)

                Image(systemName: item.location.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.body.weight(.semibold))

                HStack(spacing: 8) {
                    Text(item.location.localizedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FreshnessBadge(freshness: item.freshness)
                }
            }

            Spacer(minLength: 12)

            Text(item.quantityText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    IngredientsListView()
        .environmentObject(IngredientStore())
        .environmentObject(IngredientPresetStore())
        .environmentObject(RecommendationStore())
        .environmentObject(AppNavigationStore())
        .environmentObject(SessionStore())
}

private enum IngredientGroupKind: String, Hashable {
    case expiring
    case fresh
    case noExpiry
    case expired

    var title: String {
        switch self {
        case .expiring: return L10n.text(L10n.Ingredients.statusExpiring)
        case .fresh: return L10n.text(L10n.Ingredients.statusFresh)
        case .noExpiry: return L10n.text(L10n.Ingredients.statusNoExpiry)
        case .expired: return L10n.text(L10n.Ingredients.statusExpired)
        }
    }

    var themeKind: AppTheme.InventorySectionKind {
        switch self {
        case .expiring: return .expiring
        case .expired: return .expired
        case .fresh, .noExpiry: return .standard
        }
    }
}

private enum IngredientStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case expiringSoon
    case fresh
    case noExpiry
    case expired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expiringSoon: return L10n.text(L10n.Ingredients.statusExpiring)
        case .fresh: return L10n.text(L10n.Ingredients.statusFresh)
        case .noExpiry: return L10n.text(L10n.Ingredients.statusNoExpiry)
        case .expired: return L10n.text(L10n.Ingredients.statusExpired)
        }
    }

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
                    Toggle(L10n.text(L10n.Ingredients.filterShowArchived), isOn: $showArchived)
                }

                Section(L10n.text(L10n.Action.location)) {
                    ForEach(Ingredient.Location.allCases) { loc in
                        Toggle(isOn: binding(for: loc)) {
                            Label(loc.localizedTitle, systemImage: loc.systemImage)
                        }
                    }
                }

                Section(L10n.text(L10n.Action.status)) {
                    ForEach(IngredientStatusFilter.allCases) { status in
                        Toggle(isOn: binding(for: status)) {
                            Text(status.title)
                        }
                    }
                }

                Section(L10n.text(L10n.Action.tags)) {
                    if allTags.isEmpty {
                        Text(L10n.text(L10n.Ingredients.filterNoTags))
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
                    Button(L10n.text(L10n.Ingredients.filterClear), role: .destructive) {
                        selectedLocations.removeAll()
                        selectedStatuses.removeAll()
                        selectedTags.removeAll()
                        showArchived = false
                    }
                }
            }
            .navigationTitle(L10n.text(L10n.Ingredients.filterTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(L10n.Action.done)) { dismiss() }
                        .fontWeight(.semibold)
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
