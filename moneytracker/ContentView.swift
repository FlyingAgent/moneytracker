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
    enum Category: String, CaseIterable, Codable, Identifiable {
        case food, transport, shopping, fun, other
        var id: String { rawValue }

        var label: String {
            switch self {
            case .food: return "Food"
            case .transport: return "Transport"
            case .shopping: return "Shopping"
            case .fun: return "Fun"
            case .other: return "Other"
            }
        }

        var color: Color {
            switch self {
            case .food: return .pink
            case .transport: return .teal
            case .shopping: return .orange
            case .fun: return .indigo
            case .other: return .mint
            }
        }

        var icon: String {
            switch self {
            case .food: return "fork.knife"
            case .transport: return "tram.fill"
            case .shopping: return "bag.fill"
            case .fun: return "sparkles"
            case .other: return "circle.grid.2x2.fill"
            }
        }
    }

    let id: UUID
    var amount: Double
    var category: Category
    var note: String
    var date: Date
    var listId: UUID
    var cardId: UUID?
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
    @Published var selectedListId: UUID? {
        didSet { saveSelectedList() }
    }

    private let storageKey = "expenses_v1"
    private let listsKey = "lists_v1"
    private let cardsKey = "cards_v1"
    private let selectedListKey = "selected_list_v1"
    private let zeroEpsilon: Double = 0.0001

    init() {
        loadLists()
        load()
        loadCards()
        ensureDefaultList()
        migrateIfNeeded()
        autoBreakEmptyCards()
        if selectedListId == nil { selectedListId = lists.first?.id }
    }

    // MARK: - Expenses
    @discardableResult
    func add(amount: Double, category: Expense.Category, note: String, date: Date, cardId: UUID?) -> Bool {
        let listId = selectedListId ?? lists.first!.id
        // If a card is provided, enforce card limit
        if let cardId = cardId, let card = cards.first(where: { $0.id == cardId }) {
            guard !card.isBroken else { return false }
            let remaining = remainingAmount(for: card)
            guard amount <= remaining && remaining > zeroEpsilon else { return false }
        }
        let item = Expense(id: UUID(), amount: amount, category: category, note: note, date: date, listId: listId, cardId: cardId)
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
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Silently ignore in minimal app
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Expense].self, from: data) {
            expenses = list
            return
        }
        // Migration: legacy expenses without listId
        struct LegacyExpense: Codable {
            let id: UUID
            let amount: Double
            let category: Expense.Category
            let note: String
            let date: Date
        }
        if let legacy = try? decoder.decode([LegacyExpense].self, from: data) {
            let defaultId = ensureDefaultList().id
            expenses = legacy.map { le in
                Expense(id: le.id, amount: le.amount, category: le.category, note: le.note, date: le.date, listId: defaultId, cardId: nil)
            }
            save()
        }
    }

    // Lists persistence
    private func saveLists() {
        do {
            let data = try JSONEncoder().encode(lists)
            UserDefaults.standard.set(data, forKey: listsKey)
        } catch { }
    }

    private func loadLists() {
        guard let data = UserDefaults.standard.data(forKey: listsKey) else { return }
        if let arr = try? JSONDecoder().decode([ExpenseList].self, from: data) {
            lists = arr
        }
        if let idData = UserDefaults.standard.data(forKey: selectedListKey),
           let id = try? JSONDecoder().decode(UUID.self, from: idData) {
            selectedListId = id
        }
    }

    private func saveSelectedList() {
        guard let id = selectedListId else { return }
        if let data = try? JSONEncoder().encode(id) {
            UserDefaults.standard.set(data, forKey: selectedListKey)
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
            UserDefaults.standard.set(data, forKey: cardsKey)
        } catch { }
    }

    private func loadCards() {
        guard let data = UserDefaults.standard.data(forKey: cardsKey) else { return }
        if let arr = try? JSONDecoder().decode([Card].self, from: data) {
            cards = arr
        }
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
    @StateObject private var store = ExpenseStore()
    @State private var showingAdd = false
    @State private var selectedPeriod: Period = .month
    @State private var showingManageLists = false
    @State private var showingManageCards = false

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases) { p in
                        Text(p.shortLabel).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                // List selector moved to toolbar menu for a minimal look

                SummaryCard(title: selectedPeriod.title, total: periodTotal, currencyCode: currencyCode)

                List {
                    if filteredExpenses.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            EmptyStateView()
                                .padding(.vertical, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense, currencyCode: currencyCode)
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
                        Button("Manage Cards…") { showingManageCards = true }
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
                AddExpenseView(store: store, currencyCode: currencyCode) { amount, category, note, date, cardId in
                    _ = store.add(amount: amount, category: category, note: note, date: date, cardId: cardId)
                }
            }
            .sheet(isPresented: $showingManageLists) {
                ManageListsView(store: store)
            }
            .sheet(isPresented: $showingManageCards) {
                ManageCardsView(store: store, currencyCode: currencyCode)
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(total, format: .currency(code: currencyCode))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
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

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.pink.gradient)
            Text("Track your spending")
                .font(.headline)
            Text("Add expenses like food, transport, or fun.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let currencyCode: String

    private var title: String { expense.note.isEmpty ? expense.category.label : expense.note }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.2))
                Image(systemName: expense.category.icon)
                    .foregroundStyle(expense.category.color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount, format: .currency(code: currencyCode))
                .font(.body.weight(.semibold))
                .foregroundStyle(expense.category.color)
        }
        .padding(.vertical, 4)
    }
}

private struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: ExpenseStore
    let currencyCode: String
    var onSave: (Double, Expense.Category, String, Date, UUID?) -> Void

    @State private var amountText: String = ""
    @State private var category: Expense.Category = .food
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var selectedCardId: UUID?
    @FocusState private var amountFocused: Bool

    private var cardsInList: [Card] { store.activeCards(in: store.selectedListId) }
    private var selectedCard: Card? { cardsInList.first(where: { $0.id == selectedCardId }) }
    private var parsedAmount: Double? { parseAmount(amountText).map { max($0, 0) } }
    private var remainingText: String {
        guard let card = selectedCard else { return "" }
        let remaining = store.remainingAmount(for: card)
        return "Remaining: " + remaining.formatted(.currency(code: currencyCode)) + " of " + card.limit.formatted(.currency(code: currencyCode))
    }
    private var canSave: Bool {
        guard let amt = parsedAmount, amt > 0 else { return false }
        guard let card = selectedCard else { return false }
        return amt <= store.remainingAmount(for: card)
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

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Expense.Category.allCases) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.label)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .headerProminence(.increased)

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
        let ok = store.add(amount: amount, category: category, note: trimmedNote, date: date, cardId: cardId)
        return ok
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

// Manage Cards
private struct ManageCardsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExpenseStore
    let currencyCode: String

    @State private var name: String = ""
    @State private var amountText: String = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool
    @State private var showBroken: Bool = false

    private var parsedAmount: Double? { parseAmount(amountText).map { max($0, 0) } }
    private var activeCards: [Card] { store.activeCards(in: store.selectedListId) }
    private var archivedCards: [Card] { store.brokenCards(in: store.selectedListId) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Name") {
                    TextField("e.g. Groceries", text: $name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.words)
                }

                Section("Limit") {
                    TextField("Amount (\(currencyCode))", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                }

                Section("Cards in \(selectedListName)") {
                    if activeCards.isEmpty {
                        Text("No cards yet. Add one above.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeCards) { card in
                            CreditCardView(
                                card: card,
                                limit: card.limit,
                                spent: store.spentAmount(on: card),
                                remaining: store.remainingAmount(for: card),
                                currencyCode: currencyCode,
                                isBroken: false
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.removeCard(card)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    store.breakCard(card)
                                } label: {
                                    Label("Break", systemImage: "archivebox")
                                }
                                .tint(.indigo)
                            }
                        }
                    }
                // Toggle for broken cards (always visible at end of section)
                    Button {
                        withAnimation { showBroken.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showBroken ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.bold))
                            Text(showBroken ? "Hide Broken Cards" : "Show Broken Cards (\(archivedCards.count))")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }

                if showBroken {
                    Section("Broken") {
                        if archivedCards.isEmpty {
                            Text("No broken cards yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(archivedCards) { card in
                                CreditCardView(
                                    card: card,
                                    limit: card.limit,
                                    spent: store.spentAmount(on: card),
                                    remaining: store.remainingAmount(for: card),
                                    currencyCode: currencyCode,
                                    isBroken: true
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeCard(card)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(appBackground)
            .navigationTitle("Cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Card") {
                        if let limit = parsedAmount, limit > 0 {
                            store.addCard(name: name, limit: limit)
                            name = ""
                            amountText = ""
                            nameFocused = true
                        }
                    }
                    .disabled((parsedAmount ?? 0) <= 0)
                }
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
    }

    private var selectedListName: String {
        if let id = store.selectedListId, let name = store.lists.first(where: { $0.id == id })?.name { return name }
        return store.lists.first?.name ?? "List"
    }
}

// Stylized credit card view
private struct CreditCardView: View {
    let card: Card
    let limit: Double
    let spent: Double
    let remaining: Double
    let currencyCode: String
    var isBroken: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.white.opacity(0.9))
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .foregroundStyle(.white)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if isBroken {
                        Label("Broken", systemImage: "archivebox")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.2)))
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white.opacity(0.35))
                            .frame(width: 44, height: 28)
                    }
                }

                progressBar

                HStack(alignment: .firstTextBaseline) {
                    Text(remaining.formatted(.currency(code: currencyCode)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("remaining")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("of " + limit.formatted(.currency(code: currencyCode)))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .frame(height: 140)
        .saturation(isBroken ? 0 : 1)
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(max(spent / limit, 0), 1)
    }

    @ViewBuilder private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 6)
                Capsule()
                    .fill(.white)
                    .frame(width: width * fraction, height: 6)
            }
        }
        .frame(height: 6)
    }

    private var cardGradient: LinearGradient {
        let hue = normalizedHue(from: card.id)
        let c1 = Color(hue: hue, saturation: 0.7, brightness: 0.95)
        let c2 = Color(hue: fmod(hue + 0.12, 1.0), saturation: 0.8, brightness: 0.75)
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func normalizedHue(from id: UUID) -> Double {
        let s = id.uuidString
        let hv = abs(s.hashValue)
        // Distribute between 0.0 and 1.0
        return Double(hv % 360) / 360.0
    }
}
