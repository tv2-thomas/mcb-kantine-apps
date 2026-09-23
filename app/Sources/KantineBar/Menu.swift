import AppKit

struct Dish: Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String
    let allergens: String
    let kcal: Int
    let co2: Double
    let nutrients: [Nutrient]
    let image: NSImage?
}

struct Nutrient: Identifiable {
    let id: Int
    let name: String
    let value: String
    let isSubItem: Bool
}

struct Day: Identifiable {
    let id: String
    let date: Date
    let dishes: [Dish]
}

private struct MenuResponse: Decodable {
    let date: String
    let storeDishes: [String: [MealDTO]]
    let allDishes: [String: [String: [MealDTO]]]
}

private struct MealDTO: Decodable {
    let name: String
    let itemNumber: String?
    let categoryName: String?
    let description: String?
    let allergens: String?
    let nutrients: String?
    let image: String?
    let co2Value: Double?
    let kcal: Int?
}

enum MenuAPI {
    static let site = URL(string: "https://cozy-shortbread-2866c8.netlify.app/")!
    static let endpoint = site.appending(path: "api")

    static func fetchDays() async throws -> [Day] {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return days(from: try JSONDecoder().decode(MenuResponse.self, from: data))
    }

    private static func days(from menu: MenuResponse) -> [Day] {
        var images: [String: NSImage] = [:]
        for meal in menu.storeDishes.values.flatMap({ $0 }) {
            if let image = decodeImage(meal.image) { images[dishID(meal)] = image }
        }

        var byDay = menu.allDishes
        if byDay[menu.date] == nil, !menu.storeDishes.isEmpty {
            byDay[menu.date] = menu.storeDishes
        }

        return byDay.compactMap { key, categories in
            guard let date = DayKey.date(from: key) else { return nil }
            let dishes = categories.values.flatMap { $0 }.map { meal in
                Dish(
                    id: dishID(meal),
                    category: tidy(meal.categoryName ?? ""),
                    name: tidy(meal.name),
                    description: tidy(meal.description ?? ""),
                    allergens: tidy(meal.allergens ?? ""),
                    kcal: meal.kcal ?? 0,
                    co2: meal.co2Value ?? 0,
                    nutrients: parseNutrients(meal.nutrients ?? ""),
                    image: key == menu.date ? images[dishID(meal)] : nil
                )
            }
            .sorted { $0.category.localizedCompare($1.category) == .orderedAscending }
            return Day(id: key, date: date, dishes: dishes)
        }
        .sorted { $0.date < $1.date }
    }

    private static func dishID(_ meal: MealDTO) -> String {
        "\(meal.categoryName ?? "")|\(meal.itemNumber ?? meal.name)"
    }

    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func parseNutrients(_ text: String) -> [Nutrient] {
        text.split(separator: "\n").enumerated().compactMap { index, line in
            guard let colon = line.range(of: ": ", options: .backwards) else { return nil }
            let rawName = line[..<colon.lowerBound].trimmingCharacters(in: .whitespaces)
            let isSubItem = rawName.hasPrefix("-")
            let name = isSubItem ? rawName.dropFirst().trimmingCharacters(in: .whitespaces) : rawName
            return Nutrient(
                id: index,
                name: name.prefix(1).uppercased() + name.dropFirst(),
                value: String(line[colon.upperBound...]).replacingOccurrences(of: ".", with: ","),
                isSubItem: isSubItem
            )
        }
    }

    private static func decodeImage(_ dataURL: String?) -> NSImage? {
        guard let dataURL, let comma = dataURL.firstIndex(of: ",") else { return nil }
        guard let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])) else { return nil }
        return NSImage(data: data)
    }
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd-MM-yyyy"
        return f
    }()

    static func date(from key: String) -> Date? { formatter.date(from: key) }
    static func key(for date: Date) -> String { formatter.string(from: date) }
}
