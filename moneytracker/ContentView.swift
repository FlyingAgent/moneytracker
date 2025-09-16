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
}

struct ExpenseList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = [] {
        didSet { save() }
    }
    @Published var lists: [ExpenseList] = [] {
        didSet { saveLists() }
    }
    @Published var selectedListId: UUID? {
        didSet { saveSelectedList() }
    }

    private let storageKey = "expenses_v1"
    private let listsKey = "lists_v1"
    private let selectedListKey = "selected_list_v1"

    init() {
        loadLists()
        load()
        ensureDefaultList()
        migrateIfNeeded()
        if selectedListId == nil { selectedListId = lists.first?.id }
    }

    func add(amount: Double, category: Expense.Category, note: String, date: Date) {
        let item = Expense(id: UUID(), amount: amount, category: category, note: note, date: date, listId: selectedListId ?? lists.first!.id)
        expenses.insert(item, at: 0)
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
                Expense(id: le.id, amount: le.amount, category: le.category, note: le.note, date: le.date, listId: defaultId)
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
}

struct ContentView: View {
    @StateObject private var store = ExpenseStore()
    @State private var showingAdd = false
    @State private var selectedPeriod: Period = .month
    @State private var showingManageLists = false

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
                AddExpenseView(currencyCode: currencyCode) { amount, category, note, date in
                    store.add(amount: amount, category: category, note: note, date: date)
                }
            }
            .sheet(isPresented: $showingManageLists) {
                ManageListsView(store: store)
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

    let currencyCode: String
    var onSave: (Double, Expense.Category, String, Date) -> Void

    @State private var amountText: String = ""
    @State private var category: Expense.Category = .food
    @State private var note: String = ""
    @State private var date: Date = .now
    @FocusState private var amountFocused: Bool

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
                        if let amt = parseAmount(amountText) {
                            onSave(max(amt, 0), category, note.trimmingCharacters(in: .whitespacesAndNewlines), date)
                            dismiss()
                        }
                    }
                    .disabled(parseAmount(amountText) == nil || (parseAmount(amountText) ?? 0) <= 0)
                }
            }
            .onAppear {
                // Focus after the sheet fully presents
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    amountFocused = true
                }
            }
        }
        .toolbarBackground(appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(appBackground.ignoresSafeArea())
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
