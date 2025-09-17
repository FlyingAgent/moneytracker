//
//  ContentView.swift
//  moneytracker
//
//  Created by Joost Groen on 13.09.25.
//

import SwiftUI

// App theme (adapts to light/dark)
private let appBackground = Color(.systemBackground)

// Minimal data model
struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Double
    var categoryId: UUID
    var note: String
    var date: Date
    var listId: UUID
    var cardId: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, amount, categoryId, note, date, listId, cardId, legacyCategory, category
    }

    init(id: UUID, amount: Double, categoryId: UUID, note: String, date: Date, listId: UUID, cardId: UUID?) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.note = note
        self.date = date
        self.listId = listId
        self.cardId = cardId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        note = try container.decode(String.self, forKey: .note)
        date = try container.decode(Date.self, forKey: .date)
        listId = try container.decode(UUID.self, forKey: .listId)
        cardId = try container.decodeIfPresent(UUID.self, forKey: .cardId)

        if let decodedCategory = try container.decodeIfPresent(UUID.self, forKey: .categoryId) {
            categoryId = decodedCategory
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .legacyCategory) {
            categoryId = ExpenseCategory.defaultCategoryId(forLegacyKey: legacy)
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .category) {
            categoryId = ExpenseCategory.defaultCategoryId(forLegacyKey: legacy)
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .categoryId) {
            categoryId = ExpenseCategory.defaultCategoryId(forLegacyKey: legacy)
        } else {
            categoryId = ExpenseCategory.defaultCategoryId(forLegacyKey: "other")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(note, forKey: .note)
        try container.encode(date, forKey: .date)
        try container.encode(listId, forKey: .listId)
        try container.encodeIfPresent(cardId, forKey: .cardId)
    }
}

struct ExpenseCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var parentId: UUID?

    var color: Color { Color(hex: colorHex) }
    var icon: String { iconName }

    static func defaultCategories() -> [ExpenseCategory] {
        [
            ExpenseCategory(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Food", iconName: "fork.knife", colorHex: "FF6B81", parentId: nil),
            ExpenseCategory(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Transport", iconName: "tram.fill", colorHex: "2DD4BF", parentId: nil),
            ExpenseCategory(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Shopping", iconName: "bag.fill", colorHex: "F97316", parentId: nil),
            ExpenseCategory(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, name: "Fun", iconName: "sparkles", colorHex: "6366F1", parentId: nil),
            ExpenseCategory(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, name: "Other", iconName: "circle.grid.2x2.fill", colorHex: "34D399", parentId: nil)
        ]
    }

    static func defaultCategoryId(forLegacyKey key: String) -> UUID {
        let mapping: [String: UUID] = [
            "food": UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            "transport": UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            "shopping": UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            "fun": UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            "other": UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        ]
        return mapping[key.lowercased(), default: mapping["other"]!]
    }

    static var defaultIds: Set<UUID> {
        Set(defaultCategories().map { $0.id })
    }
}

struct Budget: Identifiable, Codable, Equatable {
    enum Scope: String, Codable {
        case list
        case category
    }

    let id: UUID
    var listId: UUID
    var categoryId: UUID?
    var amount: Double
     var scope: Scope

    init(id: UUID = UUID(), listId: UUID, categoryId: UUID? = nil, amount: Double, scope: Scope) {
        self.id = id
        self.listId = listId
        self.categoryId = categoryId
        self.amount = amount
        self.scope = scope
    }
}

private extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 3 {
            let chars = cleaned.map { String([$0, $0]) }
            cleaned = chars.joined()
        }
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 8:
            (a, r, g, b) = ((int & 0xFF000000) >> 24, (int & 0x00FF0000) >> 16, (int & 0x0000FF00) >> 8, int & 0x000000FF)
        case 6:
            (a, r, g, b) = (255, (int & 0xFF0000) >> 16, (int & 0x00FF00) >> 8, int & 0x0000FF)
        default:
            (a, r, g, b) = (255, 234, 234, 234)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct ExpenseList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

// Card model
struct Card: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var limit: Double
    var listId: UUID
    var isBroken: Bool

    init(id: UUID, name: String, limit: Double, listId: UUID, isBroken: Bool = false) {
        self.id = id
        self.name = name
        self.limit = limit
        self.listId = listId
        self.isBroken = isBroken
    }

    private enum CodingKeys: String, CodingKey { case id, name, limit, listId, isBroken }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        limit = try c.decode(Double.self, forKey: .limit)
        listId = try c.decode(UUID.self, forKey: .listId)
        isBroken = try c.decodeIfPresent(Bool.self, forKey: .isBroken) ?? false
    }
}

final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = [] {
        didSet { save() }
    }
    @Published var lists: [ExpenseList] = [] {
        didSet { saveLists() }
    }
    @Published var cards: [Card] = [] {
        didSet { saveCards() }
    }
    @Published var categories: [ExpenseCategory] = [] {
        didSet { saveCategories() }
    }
    @Published var budgets: [Budget] = [] {
        didSet { saveBudgets() }
    }
    @Published var selectedListId: UUID? {
        didSet { saveSelectedList() }
    }

    private let storageKey = "expenses_v1"
    private let listsKey = "lists_v1"
    private let cardsKey = "cards_v1"
    private let categoriesKey = "categories_v1"
    private let budgetsKey = "budgets_v1"
    private let selectedListKey = "selected_list_v1"
    private let zeroEpsilon: Double = 0.0001
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: "group.moneytracker.shared") ?? .standard
        loadCategories()
        ensureDefaultCategories()
        loadLists()
        load()
        loadCards()
        loadBudgets()
        ensureDefaultList()
        migrateIfNeeded()
        autoBreakEmptyCards()
        if selectedListId == nil { selectedListId = lists.first?.id }
    }

    // MARK: - Expenses
    @discardableResult
    func add(amount: Double, categoryId: UUID, note: String, date: Date, cardId: UUID?) -> Bool {
        let listId = selectedListId ?? lists.first!.id
        // If a card is provided, enforce card limit
        if let cardId = cardId, let card = cards.first(where: { $0.id == cardId }) {
            guard !card.isBroken else { return false }
            let remaining = remainingAmount(for: card)
            guard amount <= remaining && remaining > zeroEpsilon else { return false }
        }
        let item = Expense(id: UUID(), amount: amount, categoryId: categoryId, note: note, date: date, listId: listId, cardId: cardId)
        expenses.insert(item, at: 0)
        // Auto-break card when its remaining hits zero
        if let cardId = cardId, let idx = cards.firstIndex(where: { $0.id == cardId }) {
            if remainingAmount(for: cards[idx]) <= zeroEpsilon && !cards[idx].isBroken {
                objectWillChange.send()
                cards[idx].isBroken = true
                saveCards()
            }
        }
        return true
    }

    func remove(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
    }

    func remove(ids: Set<UUID>) {
        expenses.removeAll { ids.contains($0.id) }
    }

    var totalThisMonth: Double {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return 0 }
        return expenses
            .filter { $0.date >= startOfMonth }
            .map { $0.amount }
            .reduce(0, +)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Silently ignore in minimal app
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Expense].self, from: data) {
            expenses = list
            return
        }
        // Migration: legacy expenses without listId
        struct LegacyExpense: Codable {
            let id: UUID
            let amount: Double
            let category: String
            let note: String
            let date: Date
        }
        if let legacy = try? decoder.decode([LegacyExpense].self, from: data) {
            let defaultId = ensureDefaultList().id
            expenses = legacy.map { le in
                let mappedCategory = ExpenseCategory.defaultCategoryId(forLegacyKey: le.category)
                return Expense(id: le.id, amount: le.amount, categoryId: mappedCategory, note: le.note, date: le.date, listId: defaultId, cardId: nil)
            }
            save()
        }
    }

    // Lists persistence
    private func saveLists() {
        do {
            let data = try JSONEncoder().encode(lists)
            defaults.set(data, forKey: listsKey)
        } catch { }
    }

    private func loadLists() {
        guard let data = defaults.data(forKey: listsKey) else { return }
        if let arr = try? JSONDecoder().decode([ExpenseList].self, from: data) {
            lists = arr
        }
        if let idData = defaults.data(forKey: selectedListKey),
           let id = try? JSONDecoder().decode(UUID.self, from: idData) {
            selectedListId = id
        }
    }

    private func saveSelectedList() {
        if let id = selectedListId, let data = try? JSONEncoder().encode(id) {
            defaults.set(data, forKey: selectedListKey)
        } else {
            defaults.removeObject(forKey: selectedListKey)
        }
    }

    @discardableResult
    private func ensureDefaultList() -> ExpenseList {
        if let existing = lists.first(where: { $0.name.lowercased() == "general" }) {
            return existing
        }
        let def = ExpenseList(id: UUID(), name: "General")
        lists.insert(def, at: 0)
        if selectedListId == nil { selectedListId = def.id }
        saveLists()
        return def
    }

    private func migrateIfNeeded() {
        // Ensure all expenses have a valid listId pointing to an existing list.
        guard !lists.isEmpty else { return }
        let validIds = Set(lists.map { $0.id })
        var changed = false
        let defaultId = ensureDefaultList().id
        for i in expenses.indices {
            if !validIds.contains(expenses[i].listId) {
                expenses[i].listId = defaultId
                changed = true
            }
        }
        if changed { save() }
    }

    // List management
    func addList(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = ExpenseList(id: UUID(), name: trimmed)
        lists.append(new)
        selectedListId = new.id
    }

    // MARK: - Cards
    private func saveCards() {
        do {
            let data = try JSONEncoder().encode(cards)
            defaults.set(data, forKey: cardsKey)
        } catch { }
    }

    private func loadCards() {
        guard let data = defaults.data(forKey: cardsKey) else { return }
        if let arr = try? JSONDecoder().decode([Card].self, from: data) {
            cards = arr
        }
    }

    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            defaults.set(data, forKey: categoriesKey)
        } catch { }
    }

    private func loadCategories() {
        guard let data = defaults.data(forKey: categoriesKey) else { return }
        if let arr = try? JSONDecoder().decode([ExpenseCategory].self, from: data) {
            categories = arr
        }
    }

    private func ensureDefaultCategories() {
        let defaults = ExpenseCategory.defaultCategories()
        if categories.isEmpty {
            categories = defaults
            return
        }
        var updated = categories
        var changed = false
        for item in defaults where !updated.contains(where: { $0.id == item.id }) {
            updated.append(item)
            changed = true
        }
        if changed {
            categories = updated
        }
    }

    private func saveBudgets() {
        do {
            let data = try JSONEncoder().encode(budgets)
            defaults.set(data, forKey: budgetsKey)
        } catch { }
    }

    private func loadBudgets() {
        guard let data = defaults.data(forKey: budgetsKey) else { return }
        if let arr = try? JSONDecoder().decode([Budget].self, from: data) {
            budgets = arr
        }
    }

    func category(for id: UUID?) -> ExpenseCategory? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })
    }

    func topLevelCategories() -> [ExpenseCategory] {
        categories.filter { $0.parentId == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func subcategories(of parentId: UUID) -> [ExpenseCategory] {
        categories.filter { $0.parentId == parentId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addCategory(name: String, iconName: String, colorHex: String, parentId: UUID?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let category = ExpenseCategory(id: UUID(), name: trimmed, iconName: iconName, colorHex: colorHex, parentId: parentId)
        categories.append(category)
    }

    func updateCategory(_ category: ExpenseCategory) {
        guard let idx = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[idx] = category
    }

    func removeCategory(_ category: ExpenseCategory) {
        guard categories.count > 1 else { return }
        let fallback = ExpenseCategory.defaultCategoryId(forLegacyKey: "other")
        if ExpenseCategory.defaultIds.contains(category.id) { return }
        var idsToRemove: Set<UUID> = [category.id]
        descendantCategoryIds(for: category.id).forEach { idsToRemove.insert($0) }
        categories.removeAll { idsToRemove.contains($0.id) }
        for id in idsToRemove {
            if id == fallback { continue }
            reassignExpenses(from: id, to: fallback)
        }
        budgets.removeAll { budget in
            if let catId = budget.categoryId {
                return idsToRemove.contains(catId)
            }
            return false
        }
    }

    private func reassignExpenses(from oldCategory: UUID, to newCategory: UUID) {
        var changed = false
        for idx in expenses.indices {
            if expenses[idx].categoryId == oldCategory {
                expenses[idx].categoryId = newCategory
                changed = true
            }
        }
        if changed { save() }
    }

    private func descendantCategoryIds(for parentId: UUID) -> [UUID] {
        let children = categories.filter { $0.parentId == parentId }.map { $0.id }
        return children + children.flatMap { descendantCategoryIds(for: $0) }
    }

    func budget(for listId: UUID, categoryId: UUID?) -> Budget? {
        budgets.first(where: { $0.listId == listId && $0.categoryId == categoryId })
    }

    func setBudget(for listId: UUID, categoryId: UUID?, amount: Double, scope: Budget.Scope) {
        let cleaned = max(amount, 0)
        if let idx = budgets.firstIndex(where: { $0.listId == listId && $0.categoryId == categoryId }) {
            budgets[idx].amount = cleaned
            budgets[idx].scope = scope
        } else {
            let budget = Budget(listId: listId, categoryId: categoryId, amount: cleaned, scope: scope)
            budgets.append(budget)
        }
    }

    func removeBudget(for listId: UUID, categoryId: UUID?) {
        budgets.removeAll { $0.listId == listId && $0.categoryId == categoryId }
    }

    func budgets(for listId: UUID, scope: Budget.Scope? = nil) -> [Budget] {
        budgets.filter { budget in
            budget.listId == listId && (scope == nil || budget.scope == scope!)
        }
    }

    func spending(for listId: UUID, categoryId: UUID?, since startDate: Date?) -> Double {
        expenses
            .filter { $0.listId == listId }
            .filter { categoryId == nil ? true : $0.categoryId == categoryId }
            .filter { exp in
                guard let start = startDate else { return true }
                return exp.date >= start
            }
            .map { $0.amount }
            .reduce(0, +)
    }

    func addCard(name: String, limit: Double) {
        guard let listId = selectedListId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limit > 0 else { return }
        let card = Card(id: UUID(), name: trimmed.isEmpty ? "Card" : trimmed, limit: limit, listId: listId)
        cards.append(card)
    }

    func cards(in listId: UUID?) -> [Card] {
        guard let listId else { return [] }
        return cards.filter { $0.listId == listId }
    }

    func activeCards(in listId: UUID?) -> [Card] {
        cards(in: listId).filter { !$0.isBroken }
    }

    func brokenCards(in listId: UUID?) -> [Card] {
        cards(in: listId).filter { $0.isBroken }
    }

    func spentAmount(on card: Card) -> Double {
        expenses.filter { $0.cardId == card.id }.map { $0.amount }.reduce(0, +)
    }

    func remainingAmount(for card: Card) -> Double {
        max(card.limit - spentAmount(on: card), 0)
    }

    func breakCard(_ card: Card) {
        if let idx = cards.firstIndex(where: { $0.id == card.id }) {
            objectWillChange.send()
            cards[idx].isBroken = true
            saveCards()
        }
    }

    func restoreCard(_ card: Card) {
        if let idx = cards.firstIndex(where: { $0.id == card.id }) {
            objectWillChange.send()
            cards[idx].isBroken = false
            saveCards()
        }
    }

    func removeCard(_ card: Card) {
        objectWillChange.send()
        cards.removeAll { $0.id == card.id }
        saveCards()
    }

    private func autoBreakEmptyCards() {
        var changed = false
        for i in cards.indices {
            if !cards[i].isBroken && remainingAmount(for: cards[i]) <= zeroEpsilon {
                cards[i].isBroken = true
                changed = true
            }
        }
        if changed { saveCards() }
    }
}

struct ContentView: View {
    @AppStorage("budgetsEnabled") private var budgetsEnabled: Bool = true
    @AppStorage("categoriesEnabled") private var categoriesEnabled: Bool = true
    @StateObject private var store = ExpenseStore()
    @State private var showingAdd = false
    @State private var selectedPeriod: Period = .month
    @State private var showingManageLists = false
    @State private var showingManageCategories = false
    @State private var showingManageBudgets = false
    @State private var showingSettings = false
    @State private var selectedTab: Tab = .start

    private enum Tab: Hashable {
        case start
        case cards
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? (Locale.current.currencyCode ?? "USD") }

    // Period options
    enum Period: String, CaseIterable, Identifiable {
        case week, month, all
        var id: Self { self }

        var shortLabel: String {
            switch self {
            case .week: return "1W"
            case .month: return "1M"
            case .all: return "All"
            }
        }

        var title: String {
            switch self {
            case .week: return "Last 7 Days"
            case .month: return "Last 30 Days"
            case .all: return "All Time"
            }
        }

        var startDate: Date? {
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            switch self {
            case .week:
                return cal.date(byAdding: .day, value: -6, to: todayStart)
            case .month:
                return cal.date(byAdding: .day, value: -29, to: todayStart)
            case .all:
                return nil
            }
        }
    }

    private var filteredExpenses: [Expense] {
        let byList = store.selectedListId.flatMap { id in
            store.expenses.filter { $0.listId == id }
        } ?? store.expenses
        if let start = selectedPeriod.startDate {
            return byList.filter { $0.date >= start }
        }
        return byList
    }

    private var periodTotal: Double {
        filteredExpenses.map { $0.amount }.reduce(0, +)
    }

    private var selectedListLabel: String {
        if let id = store.selectedListId, let name = store.lists.first(where: { $0.id == id })?.name {
            return name
        }
        return store.lists.first?.name ?? "General"
    }

    private var activeListId: UUID? {
        store.selectedListId ?? store.lists.first?.id
    }

    private var categoryLookup: [UUID: ExpenseCategory] {
        Dictionary(uniqueKeysWithValues: store.categories.map { ($0.id, $0) })
    }

    private var spendByCategory: [UUID: Double] {
        filteredExpenses.reduce(into: [:]) { partialResult, expense in
            partialResult[expense.categoryId, default: 0] += expense.amount
        }
    }

    private var listBudgetSnapshot: BudgetSnapshot? {
        guard budgetsEnabled, let listId = activeListId, let budget = store.budget(for: listId, categoryId: nil), budget.amount > 0 else { return nil }
        let spent = periodTotal
        return BudgetSnapshot(id: budget.id, title: "List Budget", spent: spent, limit: budget.amount, color: Color.white.opacity(0.9), iconName: "target")
    }

    private var categoryBudgetSnapshots: [BudgetSnapshot] {
        guard budgetsEnabled, categoriesEnabled, let listId = activeListId else { return [] }
        return store.budgets(for: listId, scope: .category)
            .compactMap { budget in
                guard let categoryId = budget.categoryId, let category = categoryLookup[categoryId], budget.amount > 0 else { return nil }
                let spent = spendByCategory[categoryId] ?? 0
                return BudgetSnapshot(id: budget.id, title: category.name, spent: spent, limit: budget.amount, color: category.color, iconName: category.icon)
            }
    }

    private var alerts: [SmartAlert] {
        var items: [SmartAlert] = []
        if let budget = listBudgetSnapshot {
            let progress = budget.progress
            if progress >= 1.0 {
                items.append(SmartAlert(message: "You've exceeded the list budget.", systemImage: "exclamationmark.triangle.fill", tint: .orange))
            } else if progress >= 0.9 {
                items.append(SmartAlert(message: "You're closing in on the list budget (\(Int(progress * 100))%).", systemImage: "bell.fill", tint: .yellow))
            }
        }
        for budget in categoryBudgetSnapshots {
            let progress = budget.progress
            if progress >= 1.0 {
                items.append(SmartAlert(message: "Category \(budget.title) is over budget.", systemImage: "exclamationmark.octagon.fill", tint: .pink))
            } else if progress >= 0.9 {
                items.append(SmartAlert(message: "Category \(budget.title) budget nearly used (\(Int(progress * 100))%).", systemImage: "bell.badge.fill", tint: .orange))
            }
        }
        if let listId = activeListId {
            for card in store.activeCards(in: listId) {
                let remaining = store.remainingAmount(for: card)
                if remaining <= zeroThreshold(for: card) {
                    if remaining <= 0 {
                        items.append(SmartAlert(message: "Card \(card.name) is maxed out.", systemImage: "creditcard.fill", tint: .red))
                    } else {
                        items.append(SmartAlert(message: "Card \(card.name) has only " + remaining.formatted(.currency(code: currencyCode)) + " left.", systemImage: "creditcard", tint: .orange))
                    }
                }
            }
        }
        return items
    }

    private func zeroThreshold(for card: Card) -> Double {
        let percent = card.limit * 0.1
        let minValue = min(card.limit * 0.25, 10)
        return max(percent, minValue)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            startTab
                .tabItem {
                    Label("Start", systemImage: "house.fill")
                }
                .tag(Tab.start)

            cardsTab
                .tabItem {
                    Label("Cards", systemImage: "creditcard.fill")
                }
                .tag(Tab.cards)
        }
        .tint(.pink)
        .onChange(of: categoriesEnabled) { enabled in
            if !enabled { showingManageCategories = false }
        }
        .onChange(of: budgetsEnabled) { enabled in
            if !enabled { showingManageBudgets = false }
        }
    }

    private var startTab: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases) { p in
                        Text(p.shortLabel).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                if !alerts.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(alerts) { alert in
                            SmartAlertView(alert: alert)
                        }
                    }
                    .transition(.opacity)
                }

                SummaryCard(title: selectedPeriod.title, total: periodTotal, currencyCode: currencyCode, budget: listBudgetSnapshot)

                if budgetsEnabled && listBudgetSnapshot == nil {
                    Button {
                        showingManageBudgets = true
                    } label: {
                        Label("Set a list budget", systemImage: "plus.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }

                if budgetsEnabled && categoriesEnabled && !categoryBudgetSnapshots.isEmpty {
                    CategoryBudgetStrip(budgets: categoryBudgetSnapshots, currencyCode: currencyCode)
                }

                List {
                    if filteredExpenses.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            EmptyStateView(budgetsEnabled: budgetsEnabled)
                                .padding(.vertical, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense, category: store.category(for: expense.categoryId), currencyCode: currencyCode)
                        }
                        .onDelete { offsets in
                            let ids = Set(offsets.map { filteredExpenses[$0].id })
                            store.remove(ids: ids)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .background(appBackground)
                .listTopMargin(0)
            }
            .padding(.horizontal)
            .navigationTitle("Moneytracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section("Lists") {
                            ForEach(store.lists) { list in
                                Button(action: { store.selectedListId = list.id }) {
                                    HStack {
                                        Text(list.name)
                                        if list.id == store.selectedListId { Spacer(); Image(systemName: "checkmark").foregroundStyle(.secondary) }
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Manage Lists…") { showingManageLists = true }
                        if categoriesEnabled {
                            Button("Manage Categories…") { showingManageCategories = true }
                        }
                        if budgetsEnabled {
                            Button("Manage Budgets…") { showingManageBudgets = true }
                        }
                        Divider()
                        Button("Settings…") { showingSettings = true }
                    } label: {
                        Label(selectedListLabel, systemImage: "list.bullet")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .pink)
                            .font(.title2)
                            .accessibilityLabel("Add expense")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddExpenseView(store: store, currencyCode: currencyCode) { amount, categoryId, note, date, cardId in
                    store.add(amount: amount, categoryId: categoryId, note: note, date: date, cardId: cardId)
                }
            }
            .sheet(isPresented: $showingManageLists) {
                ManageListsView(store: store)
            }
            .sheet(isPresented: $showingManageCategories) {
                ManageCategoriesView(store: store)
            }
            .sheet(isPresented: $showingManageBudgets) {
                ManageBudgetsView(store: store, currencyCode: currencyCode, period: selectedPeriod)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }

    private var cardsTab: some View {
        NavigationStack {
            CardsView(store: store, currencyCode: currencyCode)
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }
}

private struct SummaryCard: View {
    var title: String = "This Month"
    let total: Double
    let currencyCode: String
    var budget: BudgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(total, format: .currency(code: currencyCode))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if let budget {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Budget", systemImage: budget.iconName)
                            .labelStyle(.titleAndIcon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text("Remaining " + budget.remaining.formatted(.currency(code: currencyCode)))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    ProgressView(value: min(budget.progress, 1.0))
                        .tint(.white)
                        .scaleEffect(x: 1, y: 1.4, anchor: .center)
                        .frame(height: 8)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.28))
                        )
                        .clipShape(Capsule())
                    Text("Spent " + budget.spent.formatted(.currency(code: currencyCode)) + " of " + budget.limit.formatted(.currency(code: currencyCode)))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.pink, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .pink.opacity(0.2), radius: 0, x: 0, y: 0)
    }
}

private struct BudgetSnapshot: Identifiable {
    let id: UUID
    let title: String
    let spent: Double
    let limit: Double
    let color: Color
    let iconName: String

    var progress: Double {
        guard limit > 0 else { return 0 }
        return spent / limit
    }

    var remaining: Double {
        max(limit - spent, 0)
    }
}

private struct SmartAlert: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let tint: Color
}

private struct CategoryBudgetStrip: View {
    let budgets: [BudgetSnapshot]
    let currencyCode: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(budgets) { item in
                    CategoryBudgetCard(budget: item, currencyCode: currencyCode)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CategoryBudgetCard: View {
    let budget: BudgetSnapshot
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: budget.iconName)
                    .font(.headline)
                Text(budget.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            ProgressView(value: min(budget.progress, 1.0))
                .tint(budget.color)
                .frame(height: 6)
                .background(
                    Capsule()
                        .fill(budget.color.opacity(0.18))
                )
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(budget.spent.formatted(.currency(code: currencyCode)))
                    .font(.callout.weight(.semibold))
                Text("of " + budget.limit.formatted(.currency(code: currencyCode)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CardSummaryRow: View {
    let card: Card
    let spent: Double
    let remaining: Double
    let currencyCode: String
    let isArchived: Bool

    private var progress: Double {
        guard card.limit > 0 else { return 0 }
        return min(max(spent / card.limit, 0), 1)
    }

    private var title: String {
        let trimmed = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Card" : trimmed
    }

    private var remainingLabel: String {
        if isArchived { return "Limit used" }
        return remaining.formatted(.currency(code: currencyCode)) + " left"
    }

    private var percentText: String {
        let percent = Int(round(progress * 100))
        return "\(percent)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(card.limit.formatted(.currency(code: currencyCode)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(remainingLabel)
                .font(.subheadline)
                .foregroundStyle(isArchived ? .secondary : .primary)

            ProgressView(value: progress)
                .tint(isArchived ? .gray : .pink)

            HStack {
                Text("Spent " + spent.formatted(.currency(code: currencyCode)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !isArchived {
                    Text(percentText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct SmartAlertView: View {
    let alert: SmartAlert

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(8)
                .background(Circle().fill(alert.tint))
            Text(alert.message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct EmptyStateView: View {
    let budgetsEnabled: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.pink.gradient)
            Text("Track your spending")
                .font(.headline)
            Text(budgetsEnabled ? "Add expenses to start watching your budgets." : "Add expenses to start tracking your spending.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let category: ExpenseCategory?
    let currencyCode: String
    @AppStorage("categoriesEnabled") private var categoriesEnabled: Bool = true

    private var title: String {
        if !expense.note.isEmpty { return expense.note }
        if categoriesEnabled { return category?.name ?? "Uncategorized" }
        return "Expense"
    }

    private var tintColor: Color {
        if categoriesEnabled, let color = category?.color { return color }
        return .accentColor
    }

    private var iconName: String {
        if categoriesEnabled, let icon = category?.icon { return icon }
        return "dollarsign.circle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.2))
                Image(systemName: iconName)
                    .foregroundStyle(tintColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if categoriesEnabled, let categoryName = category?.name, expense.note.isEmpty {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount, format: .currency(code: currencyCode))
                .font(.body.weight(.semibold))
                .foregroundStyle(tintColor)
        }
        .padding(.vertical, 4)
    }
}

private struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: ExpenseStore
    let currencyCode: String
    var onSave: (Double, UUID, String, Date, UUID?) -> Bool

    @AppStorage("categoriesEnabled") private var categoriesEnabled: Bool = true
    @State private var amountText: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var selectedCardId: UUID?
    @FocusState private var amountFocused: Bool

    private var cardsInList: [Card] { store.activeCards(in: store.selectedListId) }
    private var selectedCard: Card? { cardsInList.first(where: { $0.id == selectedCardId }) }
    private var fallbackCategoryId: UUID { store.categories.first?.id ?? ExpenseCategory.defaultCategoryId(forLegacyKey: "other") }
    private var orderedCategories: [ExpenseCategory] {
        store.topLevelCategories().flatMap { parent in
            [parent] + store.subcategories(of: parent.id)
        }
    }
    private var selectedCategory: ExpenseCategory? {
        store.category(for: selectedCategoryId) ?? store.category(for: fallbackCategoryId)
    }
    private var parsedAmount: Double? { parseAmount(amountText).map { max($0, 0) } }
    private var remainingText: String {
        guard let card = selectedCard else { return "" }
        let remaining = store.remainingAmount(for: card)
        return "Remaining: " + remaining.formatted(.currency(code: currencyCode)) + " of " + card.limit.formatted(.currency(code: currencyCode))
    }
    private var canSave: Bool {
        guard let amt = parsedAmount, amt > 0 else { return false }
        guard let card = selectedCard else { return false }
        if categoriesEnabled && selectedCategory == nil { return false }
        return amt <= store.remainingAmount(for: card)
    }

    private func displayName(for category: ExpenseCategory) -> String {
        if let parentId = category.parentId, let parent = store.category(for: parentId) {
            return "\(parent.name) › \(category.name)"
        }
        return category.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount (\(currencyCode))", text: $amountText)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($amountFocused)
                }
                .headerProminence(.increased)

                Section("Card") {
                    if cardsInList.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No cards available in this list.")
                            Text("Create one via Manage Cards.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Card", selection: $selectedCardId) {
                            ForEach(cardsInList) { card in
                                let rem = store.remainingAmount(for: card)
                                Text("\(card.name) – " + rem.formatted(.currency(code: currencyCode)))
                                    .tag(Optional(card.id))
                            }
                        }
                        .pickerStyle(.menu)
                        if let _ = selectedCard {
                            Text(remainingText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .headerProminence(.increased)

                if categoriesEnabled {
                    Section("Category") {
                        let selection = Binding<UUID>(
                            get: {
                                selectedCategory?.id ?? orderedCategories.first?.id ?? fallbackCategoryId
                            },
                            set: { value in
                                selectedCategoryId = value
                            }
                        )
                        Picker("Category", selection: selection) {
                            ForEach(orderedCategories) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(displayName(for: category))
                                }
                                .tag(category.id)
                            }
                        }
                        .pickerStyle(.menu)
                        if let category = selectedCategory {
                            Text("\(displayName(for: category))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .headerProminence(.increased)
                }

                Section("Details") {
                    TextField("Note (optional)", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                .headerProminence(.increased)
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color(.secondarySystemBackground))
            .listSectionSeparator(.visible, edges: .all)
            .listSectionSeparatorTint(Color(.separator))
            .listRowSeparator(.visible)
            .listRowSeparatorTint(Color(.separator))
            .formStyle(.grouped)
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amt = parsedAmount {
                            if onAttemptSave(amount: amt) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Focus after the sheet fully presents
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    amountFocused = true
                }
                if selectedCardId == nil {
                    selectedCardId = cardsInList.first?.id
                }
                if selectedCategoryId == nil {
                    selectedCategoryId = orderedCategories.first?.id ?? fallbackCategoryId
                }
            }
            .onChange(of: store.selectedListId) { _ in
                // Reset selection when changing lists while adding
                selectedCardId = cardsInList.first?.id
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }

    private func onAttemptSave(amount: Double) -> Bool {
        guard let cardId = selectedCardId else { return false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryId = selectedCategory?.id ?? fallbackCategoryId
        return onSave(amount, categoryId, trimmedNote, date, cardId)
    }
}

// Helpers
private extension View {
    @ViewBuilder
    func listTopMargin(_ value: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            self.contentMargins(.top, value, for: .scrollContent)
        } else {
            self
        }
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

// Parsing helpers
private func parseAmount(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    // Try decimal number according to current locale
    let dec = NumberFormatter()
    dec.locale = .current
    dec.numberStyle = .decimal
    dec.generatesDecimalNumbers = true
    if let n = dec.number(from: trimmed)?.doubleValue { return n }

    // Try currency style in case user typed symbol
    let cur = NumberFormatter()
    cur.locale = .current
    cur.numberStyle = .currency
    cur.generatesDecimalNumbers = true
    if let n = cur.number(from: trimmed)?.doubleValue { return n }

    // Fallback: remove everything except digits and decimal separator
    let sep = dec.decimalSeparator ?? "."
    let allowed = Set(("0123456789" + sep))
    let cleaned = trimmed.filter { allowed.contains($0) }
    if let n = dec.number(from: cleaned)?.doubleValue { return n }
    return Double(cleaned.replacingOccurrences(of: sep, with: "."))
}

#Preview {
    ContentView()
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("budgetsEnabled") private var budgetsEnabled: Bool = true
    @AppStorage("categoriesEnabled") private var categoriesEnabled: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Systems") {
                    Toggle("Enable Budgets", isOn: $budgetsEnabled)
                    Toggle("Enable Categories", isOn: $categoriesEnabled)
                }
                if !budgetsEnabled || !categoriesEnabled {
                    Section("Details") {
                        if !budgetsEnabled {
                            Text("List and category budgets stay hidden while disabled. Existing values are kept for later.")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                        if !categoriesEnabled {
                            Text("Expenses use a default category while the category system is off.")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }
}

// Manage Lists
private struct ManageListsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExpenseStore

    @State private var newListName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Create New List") {
                    HStack {
                        TextField("List name (e.g. Holiday 2022)", text: $newListName)
                        Button("Add") {
                            store.addList(named: newListName)
                            newListName = ""
                        }
                        .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Your Lists") {
                    ForEach(store.lists) { list in
                        HStack {
                            Text(list.name)
                            if list.id == store.selectedListId { Spacer(); Image(systemName: "checkmark").foregroundStyle(.secondary) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectedListId = list.id }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }
}

// Manage Categories
private struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExpenseStore

    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColor: String = ExpenseCategory.defaultCategories().first?.colorHex ?? "FF6B81"
    @State private var parentId: UUID?

    private let iconOptions = [
        "tag.fill", "cart.fill", "fork.knife", "sparkles", "house.fill", "car.fill", "airplane", "flame.fill", "gamecontroller.fill", "gift.fill"
    ]

    private let colorOptions = [
        "FF6B81", "F97316", "22D3EE", "A855F7", "14B8A6", "FACC15", "EF4444", "10B981", "0EA5E9"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Category") {
                    TextField("Name (e.g. Coffee)", text: $name)
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(readableName(for: icon))
                            }
                            .tag(icon)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Color", selection: $selectedColor) {
                        ForEach(colorOptions, id: \.self) { hex in
                            HStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 16, height: 16)
                                Text(hex)
                            }
                            .tag(hex)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Parent (optional)", selection: $parentId) {
                        Text("No parent").tag(UUID?.none)
                        ForEach(store.topLevelCategories()) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        addCategory()
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Your Categories") {
                    ForEach(store.topLevelCategories()) { category in
                        CategoryListRow(store: store, category: category)
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }

    private func addCategory() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addCategory(name: trimmed, iconName: selectedIcon, colorHex: selectedColor, parentId: parentId)
        name = ""
        parentId = nil
    }

    private func readableName(for icon: String) -> String {
        icon.replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".circle", with: "")
            .replacingOccurrences(of: ".square", with: "")
            .replacingOccurrences(of: ".triangle", with: "")
            .replacingOccurrences(of: ".diamond", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
    }
}

private struct CategoryListRow: View {
    @ObservedObject var store: ExpenseStore
    let category: ExpenseCategory

    private var isDefault: Bool { ExpenseCategory.defaultIds.contains(category.id) }
    private var children: [ExpenseCategory] { store.subcategories(of: category.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 12, height: 12)
                Text(category.name)
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: category.icon)
                    .foregroundStyle(.secondary)
            }
            if !children.isEmpty {
                ForEach(children) { child in
                    CategoryChildRow(store: store, category: child)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isDefault {
                Button(role: .destructive) {
                    store.removeCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

private struct CategoryChildRow: View {
    @ObservedObject var store: ExpenseStore
    let category: ExpenseCategory

    private var isDefault: Bool { ExpenseCategory.defaultIds.contains(category.id) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Circle()
                .fill(category.color)
                .frame(width: 10, height: 10)
            Text(category.name)
                .font(.subheadline)
            Spacer()
            Image(systemName: category.icon)
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isDefault {
                Button(role: .destructive) {
                    store.removeCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// Cards tab
private struct CardsView: View {
    @ObservedObject var store: ExpenseStore
    let currencyCode: String

    private enum AmountMode: Equatable {
        case preset(Int)
        case custom
    }

    private let presetAmounts: [Double] = [5, 10, 15, 20]
    private let defaultPresetIndex: Int = 1

    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var showArchive: Bool = false
    @State private var showInfo: Bool = false
    @State private var amountMode: AmountMode = .preset(1)
    @FocusState private var amountFocused: Bool

    private var parsedAmount: Double? { parseAmount(amountText).map { max($0, 0) } }
    private var canCreateCard: Bool { (parsedAmount ?? 0) > 0 }
    private var activeCards: [Card] { store.activeCards(in: store.selectedListId) }
    private var archivedCards: [Card] { store.brokenCards(in: store.selectedListId) }

    private var selectedListName: String {
        if let id = store.selectedListId, let name = store.lists.first(where: { $0.id == id })?.name { return name }
        return store.lists.first?.name ?? "List"
    }

    var body: some View {
        List {
            Section {
                Menu {
                    ForEach(store.lists) { list in
                        Button(action: { store.selectedListId = list.id }) {
                            HStack {
                                Text(list.name)
                                if list.id == store.selectedListId { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label("List", systemImage: "list.bullet")
                            .font(.subheadline)
                        Spacer()
                        Text(selectedListName)
                            .font(.headline)
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Groceries", text: $name)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: sliderBinding, in: 0...Double(presetAmounts.count - 1), step: 1) {
                            Text("")
                        } minimumValueLabel: {
                            Text(presetLabel(for: 0))
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text(presetLabel(for: presetAmounts.count - 1))
                                .font(.caption2)
                        }
                        HStack {
                            ForEach(presetAmounts.indices, id: \.self) { idx in
                                Text(presetLabel(for: idx))
                                    .font(.caption2)
                                    .fontWeight(idx == selectedPresetIndex ? .semibold : .regular)
                                    .foregroundStyle(idx == selectedPresetIndex ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount (\(currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .submitLabel(.done)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .onSubmit(addCard)
                    }

                    Button {
                        addCard()
                    } label: {
                        Label("Create Card", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateCard)
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    Text("New Card")
                    Spacer()
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Card info")
                }
            }

            Section(activeCards.isEmpty ? "Cards" : "Active Cards") {
                if activeCards.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No cards yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Create a card above to track a small budget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(activeCards) { card in
                        CardSummaryRow(
                            card: card,
                            spent: store.spentAmount(on: card),
                            remaining: store.remainingAmount(for: card),
                            currencyCode: currencyCode,
                            isArchived: false
                        )
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Used") {
                                store.breakCard(card)
                            }
                            .tint(.indigo)

                            Button(role: .destructive) {
                                store.removeCard(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !archivedCards.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showArchive) {
                        ForEach(archivedCards) { card in
                            CardSummaryRow(
                                card: card,
                                spent: store.spentAmount(on: card),
                                remaining: store.remainingAmount(for: card),
                                currencyCode: currencyCode,
                                isArchived: true
                            )
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Restore") {
                                    store.restoreCard(card)
                                }
                                .tint(.teal)

                                Button(role: .destructive) {
                                    store.removeCard(card)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Label(showArchive ? "Hide used cards" : "Show used cards", systemImage: showArchive ? "chevron.down" : "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboardCompat()
        .background(appBackground)
        .navigationTitle("Cards")
        .onAppear(perform: loadDefaults)
        .onChange(of: amountFocused) { focused in
            if focused { amountMode = .custom }
        }
        .alert("Cards", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Cards act like mini wallets. Give one a budget and mark it used when it's empty.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
    }

    private func addCard() {
        guard let limit = parsedAmount, limit > 0 else { return }
        store.addCard(name: name, limit: limit)
        name = ""
        amountMode = .preset(defaultPresetIndex)
        amountText = amountString(from: presetAmounts[defaultPresetIndex])
        amountFocused = false
    }

    private func loadDefaults() {
        if amountText.isEmpty {
            amountText = amountString(from: presetAmounts[defaultPresetIndex])
            amountMode = .preset(defaultPresetIndex)
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(selectedPresetIndex) },
            set: { newValue in
                let rounded = Int(round(newValue))
                let clamped = max(0, min(presetAmounts.count - 1, rounded))
                amountMode = .preset(clamped)
                amountText = amountString(from: presetAmounts[clamped])
                amountFocused = false
            }
        )
    }

    private var selectedPresetIndex: Int {
        switch amountMode {
        case .preset(let idx):
            return max(0, min(presetAmounts.count - 1, idx))
        case .custom:
            guard let value = parsedAmount else { return defaultPresetIndex }
            if let first = presetAmounts.first, value <= first { return 0 }
            if let last = presetAmounts.last, value >= last { return presetAmounts.count - 1 }
            let nearest = presetAmounts.enumerated().min(by: { abs($0.element - value) < abs($1.element - value) })
            return nearest?.offset ?? defaultPresetIndex
        }
    }

    private func presetLabel(for index: Int) -> String {
        guard presetAmounts.indices.contains(index) else { return "" }
        let amount = presetAmounts[index]
        return amountString(from: amount) + "€"
    }

    private func amountString(from amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}

// Manage Budgets
private struct ManageBudgetsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExpenseStore
    let currencyCode: String
    let period: ContentView.Period

    @AppStorage("categoriesEnabled") private var categoriesEnabled: Bool = true
    @State private var listBudgetText: String = ""
    @State private var categoryBudgetTexts: [UUID: String] = [:]

    private var listId: UUID? { store.selectedListId ?? store.lists.first?.id }
    private var listName: String {
        if let id = listId, let list = store.lists.first(where: { $0.id == id }) { return list.name }
        return store.lists.first?.name ?? "List"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let listId {
                    Section("List Budget") {
                        BudgetInputRow(title: listName, spent: store.spending(for: listId, categoryId: nil, since: period.startDate), currencyCode: currencyCode, text: $listBudgetText, color: .pink)
                        Button(role: .destructive) {
                            store.removeBudget(for: listId, categoryId: nil)
                            listBudgetText = ""
                        } label: {
                            Label("Remove Budget", systemImage: "trash")
                        }
                        .disabled(store.budget(for: listId, categoryId: nil) == nil)
                    }

                    if categoriesEnabled {
                        Section("Category Budgets") {
                            if store.categories.isEmpty {
                                Text("Create categories first.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(store.topLevelCategories()) { category in
                                    CategoryBudgetInputGroup(store: store, category: category, listId: listId, currencyCode: currencyCode, period: period, textProvider: binding(for:))
                                }
                            }
                        }
                    } else {
                        Section("Category Budgets") {
                            Text("Enable categories in Settings to assign category budgets.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Create a list before setting budgets.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { persistBudgets() }
                        .disabled(listId == nil)
                }
            }
        }
        .onAppear(perform: loadCurrentBudgets)
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }

    private func binding(for category: ExpenseCategory) -> Binding<String> {
        Binding(
            get: { categoryBudgetTexts[category.id] ?? defaultText(for: category) },
            set: { categoryBudgetTexts[category.id] = $0 }
        )
    }

    private func defaultText(for category: ExpenseCategory) -> String {
        guard let listId else { return "" }
        if let budget = store.budget(for: listId, categoryId: category.id) {
            return formatAmount(budget.amount)
        }
        return ""
    }

    private func loadCurrentBudgets() {
        guard let listId else { return }
        if let budget = store.budget(for: listId, categoryId: nil) {
            listBudgetText = formatAmount(budget.amount)
        } else {
            listBudgetText = ""
        }
        if categoriesEnabled {
            var texts: [UUID: String] = [:]
            for category in store.categories {
                if let budget = store.budget(for: listId, categoryId: category.id) {
                    texts[category.id] = formatAmount(budget.amount)
                }
            }
            categoryBudgetTexts = texts
        } else {
            categoryBudgetTexts = [:]
        }
    }

    private func persistBudgets() {
        guard let listId else { return }
        if let amount = parseAmount(listBudgetText), amount > 0 {
            store.setBudget(for: listId, categoryId: nil, amount: amount, scope: .list)
        } else {
            store.removeBudget(for: listId, categoryId: nil)
        }

        if categoriesEnabled {
            for category in store.categories {
                let text = categoryBudgetTexts[category.id] ?? ""
                if let amount = parseAmount(text), amount > 0 {
                    store.setBudget(for: listId, categoryId: category.id, amount: amount, scope: .category)
                } else {
                    store.removeBudget(for: listId, categoryId: category.id)
                }
            }
        }
        loadCurrentBudgets()
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }
}

private struct BudgetInputRow: View {
    let title: String
    let spent: Double
    let currencyCode: String
    @Binding var text: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
            }
            HStack {
                TextField("Budget", text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("\(spent.formatted(.currency(code: currencyCode))) spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(color)
                .frame(height: 6)
                .background(
                    Capsule()
                        .fill(color.opacity(0.2))
                )
                .clipShape(Capsule())
        }
    }

    private var progress: Double {
        guard let amount = parseAmount(text), amount > 0 else { return 0 }
        return min(spent / amount, 1)
    }
}

private struct CategoryBudgetInputGroup: View {
    @ObservedObject var store: ExpenseStore
    let category: ExpenseCategory
    let listId: UUID
    let currencyCode: String
    let period: ContentView.Period
    let textProvider: (ExpenseCategory) -> Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BudgetInputRow(title: category.name, spent: store.spending(for: listId, categoryId: category.id, since: period.startDate), currencyCode: currencyCode, text: textProvider(category), color: category.color)
            let children = store.subcategories(of: category.id)
            if !children.isEmpty {
                ForEach(children) { child in
                    BudgetInputRow(title: child.name, spent: store.spending(for: listId, categoryId: child.id, since: period.startDate), currencyCode: currencyCode, text: textProvider(child), color: child.color)
                        .padding(.leading, 16)
                }
            }
        }
    }
}

// Stylized credit card view
