import Foundation
import Observation

@MainActor
@Observable
final class MenuStore {
    private(set) var days: [Day] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var selectedID: String?
    private(set) var openDishID: String?

    private var fetchedAt: Date?
    private var fetchedDayKey: String?

    var selectedDay: Day? { days.first { $0.id == selectedID } ?? days.first }
    var openDish: Dish? { selectedDay?.dishes.first { $0.id == openDishID } }
    var todayKey: String { DayKey.key(for: .now) }

    func refreshIfStale() async {
        let stale = fetchedAt.map { Date.now.timeIntervalSince($0) > 15 * 60 } ?? true
        if stale || fetchedDayKey != todayKey || error != nil {
            await refresh()
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await MenuAPI.fetchDays()
            let rolledOver = fetchedDayKey != nil && fetchedDayKey != todayKey
            days = fetched
            error = nil
            fetchedAt = .now
            fetchedDayKey = todayKey
            if rolledOver || !days.contains(where: { $0.id == selectedID }) {
                select(defaultDayID())
            }
        } catch {
            self.error = "Fikk ikke hentet menyen"
        }
    }

    func select(_ id: String?) {
        selectedID = id
        openDishID = nil
    }

    func selectAdjacentDay(_ offset: Int) {
        guard let current = days.firstIndex(where: { $0.id == selectedDay?.id }) else { return }
        let target = min(max(current + offset, 0), days.count - 1)
        if target != current { select(days[target].id) }
    }

    func openDish(_ id: String) {
        openDishID = id
    }

    func openDish(at index: Int) {
        guard let dishes = selectedDay?.dishes, dishes.indices.contains(index) else { return }
        openDishID = dishes[index].id
    }

    func closeDish() {
        openDishID = nil
    }

    private func defaultDayID() -> String? {
        let today = Calendar.current.startOfDay(for: .now)
        return (days.first { $0.date >= today } ?? days.last)?.id
    }
}
