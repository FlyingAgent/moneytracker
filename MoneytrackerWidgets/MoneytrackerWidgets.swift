import WidgetKit
import SwiftUI

private let sharedSuiteName = "group.moneytracker.shared"

struct BudgetEntry: TimelineEntry {
    let date: Date
    let listName: String
    let currencyCode: String
    let spent: Double
    let limit: Double
    let categoryBudgets: [CategorySnapshot]
    let cards: [CardSnapshot]

    var progress: Double {
        guard limit > 0 else { return 0 }
        return spent / limit
    }

    var remaining: Double {
        max(limit - spent, 0)
    }

    static var placeholder: BudgetEntry {
        BudgetEntry(
            date: Date(),
            listName: "Holiday",
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            spent: 420,
            limit: 600,
            categoryBudgets: [
                CategorySnapshot(id: UUID(), name: "Food", color: Color.pink, spent: 180, limit: 250),
                CategorySnapshot(id: UUID(), name: "Fun", color: Color.purple, spent: 120, limit: 200)
            ],
            cards: [CardSnapshot(id: UUID(), name: "Travel", remaining: 120, limit: 500)]
        )
    }
}

struct CategorySnapshot: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let spent: Double
    let limit: Double

    var progress: Double {
        guard limit > 0 else { return 0 }
        return spent / limit
    }

    var remaining: Double {
        max(limit - spent, 0)
    }
}

struct CardSnapshot: Identifiable {
    let id: UUID
    let name: String
    let remaining: Double
    let limit: Double

    var used: Double {
        max(limit - remaining, 0)
    }

    var progress: Double {
        guard limit > 0 else { return 0 }
        return used / limit
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(fetchEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = fetchEntry() ?? .placeholder
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fetchEntry() -> BudgetEntry? {
        let defaults = UserDefaults(suiteName: sharedSuiteName) ?? .standard
        let decoder = JSONDecoder()
        guard let listsData = defaults.data(forKey: "lists_v1"),
              let lists = try? decoder.decode([StoredList].self, from: listsData),
              !lists.isEmpty else {
            return nil
        }

        let listId: UUID
        if let listData = defaults.data(forKey: "selected_list_v1"),
           let id = try? decoder.decode(UUID.self, from: listData) {
            listId = id
        } else {
            listId = lists[0].id
        }
        let listName = lists.first(where: { $0.id == listId })?.name ?? lists[0].name

        let expenses = (defaults.data(forKey: "expenses_v1").flatMap { try? decoder.decode([StoredExpense].self, from: $0) }) ?? []
        let categories = (defaults.data(forKey: "categories_v1").flatMap { try? decoder.decode([StoredCategory].self, from: $0) }) ?? []
        let budgets = (defaults.data(forKey: "budgets_v1").flatMap { try? decoder.decode([StoredBudget].self, from: $0) }) ?? []
        let cards = (defaults.data(forKey: "cards_v1").flatMap { try? decoder.decode([StoredCard].self, from: $0) }) ?? []

        let startOfPeriod = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date())) ?? Date().addingTimeInterval(-29 * 24 * 60 * 60)
        let periodExpenses = expenses.filter { $0.listId == listId && $0.date >= startOfPeriod }
        let spentTotal = periodExpenses.reduce(0) { $0 + $1.amount }

        let listBudget = budgets.first(where: { $0.listId == listId && $0.categoryId == nil })
        let limit = listBudget?.amount ?? 0

        let categorySpend = Dictionary(grouping: periodExpenses, by: { $0.categoryId })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let categorySnapshots = budgets
            .filter { $0.listId == listId && $0.scope == .category }
            .compactMap { budget -> CategorySnapshot? in
                guard let catId = budget.categoryId,
                      let category = categories.first(where: { $0.id == catId }),
                      budget.amount > 0 else { return nil }
                let spent = categorySpend[catId] ?? 0
                return CategorySnapshot(id: budget.id, name: category.name, color: Color(hex: category.colorHex), spent: spent, limit: budget.amount)
            }
            .sorted { $0.progress > $1.progress }

        let cardExpenses = Dictionary(grouping: expenses.filter { $0.listId == listId && $0.cardId != nil }, by: { $0.cardId! })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let cardSnapshots = cards
            .filter { $0.listId == listId && !$0.isBroken }
            .map { card -> CardSnapshot in
                let spent = cardExpenses[card.id] ?? 0
                let remaining = max(card.limit - spent, 0)
                return CardSnapshot(id: card.id, name: card.name.isEmpty ? "Card" : card.name, remaining: remaining, limit: card.limit)
            }
            .sorted { $0.remaining < $1.remaining }

        return BudgetEntry(
            date: Date(),
            listName: listName,
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            spent: spentTotal,
            limit: limit,
            categoryBudgets: Array(categorySnapshots.prefix(3)),
            cards: cardSnapshots
        )
    }
}

struct BudgetOverviewEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            BudgetMediumView(entry: entry)
        case .accessoryRectangular:
            BudgetAccessoryRectangularView(entry: entry)
        default:
            BudgetSmallView(entry: entry)
        }
    }
}

struct CardStatusEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .accessoryInline:
            CardInlineView(entry: entry)
        case .accessoryCircular:
            CardCircularView(entry: entry)
        default:
            CardSmallView(entry: entry)
        }
    }
}

struct BudgetSmallView: View {
    var entry: BudgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 8) {
                Text(entry.listName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text(entry.spent, format: .currency(code: entry.currencyCode))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                if entry.limit > 0 {
                    Gauge(value: min(entry.progress, 1), label: { }) {
                        Text("Spent")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(.white)
                    Text("of " + entry.limit.formatted(.currency(code: entry.currencyCode)))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Set a list budget in Moneytracker")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }
}

struct BudgetMediumView: View {
    var entry: BudgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.listName)
                        .font(.headline)
                    if entry.limit > 0 {
                        Text("Spent " + entry.spent.formatted(.currency(code: entry.currencyCode)) + " of " + entry.limit.formatted(.currency(code: entry.currencyCode)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Set a list budget to track progress.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if entry.limit > 0 {
                ProgressView(value: min(entry.progress, 1))
                    .tint(.pink)
                    .frame(height: 6)
                    .background(Capsule().fill(Color.pink.opacity(0.2)))
                    .clipShape(Capsule())
            }

            if entry.categoryBudgets.isEmpty {
                Text("Set category budgets to see more detail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.categoryBudgets) { budget in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(budget.color)
                                .frame(width: 10, height: 10)
                            Text(budget.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(budget.remaining.formatted(.currency(code: entry.currencyCode)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(budget.progress, 1))
                            .tint(budget.color)
                            .frame(height: 4)
                            .background(Capsule().fill(budget.color.opacity(0.2)))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(ContainerRelativeShape().fill(Color(.systemBackground)))
    }
}

struct BudgetAccessoryRectangularView: View {
    var entry: BudgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.listName)
                .font(.headline)
            if entry.limit > 0 {
                ProgressView(value: min(entry.progress, 1))
                    .tint(.pink)
                Text("\(entry.spent.formatted(.currency(code: entry.currencyCode))) of \(entry.limit.formatted(.currency(code: entry.currencyCode)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.spent, format: .currency(code: entry.currencyCode))
                    .font(.headline)
                Text("Add a budget in the app to track progress here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CardSmallView: View {
    var entry: BudgetEntry

    private var primaryCard: CardSnapshot? { entry.cards.first }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))
            VStack(spacing: 8) {
                if let card = primaryCard {
                    Text(card.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    ProgressView(value: min(card.progress, 1))
                        .tint(.indigo)
                        .frame(height: 6)
                        .background(Capsule().fill(Color.indigo.opacity(0.2)))
                        .clipShape(Capsule())
                    Text(card.remaining, format: .currency(code: entry.currencyCode))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.indigo)
                    Text("Remaining of " + card.limit.formatted(.currency(code: entry.currencyCode)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No cards available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

struct CardInlineView: View {
    var entry: BudgetEntry

    private var primaryCard: CardSnapshot? { entry.cards.first }

    var body: some View {
        if let card = primaryCard {
            Text("\(card.name): " + card.remaining.formatted(.currency(code: entry.currencyCode)))
        } else {
            Text("No cards")
        }
    }
}

struct CardCircularView: View {
    var entry: BudgetEntry

    private var primaryCard: CardSnapshot? { entry.cards.first }

    var body: some View {
        if let card = primaryCard {
            Gauge(value: min(card.progress, 1)) {
                Text(card.name)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            Image(systemName: "creditcard")
        }
    }
}

@main
struct MoneytrackerWidgets: WidgetBundle {
    var body: some Widget {
        BudgetOverviewWidget()
        CardStatusWidget()
    }
}

struct BudgetOverviewWidget: Widget {
    let kind: String = "BudgetOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BudgetOverviewEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("Track list and category budgets at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CardStatusWidget: Widget {
    let kind: String = "CardStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CardStatusEntryView(entry: entry)
        }
        .configurationDisplayName("Card Status")
        .description("Check remaining balance on your cards.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular])
    }
}

private struct StoredExpense: Decodable {
    let id: UUID
    let amount: Double
    let categoryId: UUID
    let note: String
    let date: Date
    let listId: UUID
    let cardId: UUID?
}

private struct StoredList: Decodable {
    let id: UUID
    let name: String
}

private struct StoredCategory: Decodable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String
    let parentId: UUID?
}

private struct StoredBudget: Decodable {
    enum Scope: String, Decodable {
        case list
        case category
    }

    let id: UUID
    let listId: UUID
    let categoryId: UUID?
    let amount: Double
    let scope: Scope
}

private struct StoredCard: Decodable {
    let id: UUID
    let name: String
    let limit: Double
    let listId: UUID
    let isBroken: Bool
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
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct MoneytrackerWidgets_Previews: PreviewProvider {
    static var previews: some View {
        BudgetOverviewEntryView(entry: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        BudgetOverviewEntryView(entry: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        CardStatusEntryView(entry: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
