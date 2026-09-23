import SwiftUI

enum DishStyle {
    private static let emojiRules: [(String, [String])] = [
        ("🍕", ["pizza"]),
        ("🍔", ["burger"]),
        ("🌮", ["taco", "burrito", "quesadilla", "nachos", "tortilla"]),
        ("🍣", ["sushi", "poke"]),
        ("🍲", ["suppe", "soup", "gryte", "one pot", "stew", "chili"]),
        ("🍛", ["curry", "tikka", "dal ", "masala"]),
        ("🍜", ["ramen", "nudler", "noodle", "wok", "stir-fry", "pad thai", "udon"]),
        ("🧆", ["falafel"]),
        ("🥗", ["salat", "salad", "bowl"]),
        ("🍝", ["pasta", "spaghetti", "lasagne", "penne", "tagliatelle", "risotto", "gnocchi"]),
        ("🦐", ["reke", "scampi"]),
        ("🐟", ["fisk", "laks", "torsk", "sei", "fish", "tuna", "tunfisk"]),
        ("🍗", ["kylling", "chicken", "kalkun"]),
        ("🥩", ["biff", "storfe", "beef", "lam", "entrecôte", "kjøtt"]),
        ("🐷", ["svin", "pork", "ribbe", "bacon", "skinke"]),
        ("🥙", ["kebab", "gyros", "pita", "wrap"]),
        ("🫘", ["bønne", "kikert", "chickpea", "linse"]),
        ("🥪", ["sandwich", "baguette", "toast"]),
    ]

    static func emoji(for dish: Dish) -> String {
        let text = "\(dish.name) \(dish.category)".lowercased()
        return emojiRules.first { _, words in words.contains { text.contains($0) } }?.0 ?? "🍽️"
    }

    static func tint(for category: String) -> Color {
        Color(hue: hue(for: category), saturation: 0.55, brightness: 0.9)
    }

    static func badge(for category: String) -> Color {
        Color(hue: hue(for: category), saturation: 0.75, brightness: 0.7)
    }

    private static func hue(for category: String) -> Double {
        let seed = category.unicodeScalars.reduce(UInt32(7)) { $0 &* 31 &+ $1.value }
        return Double(seed % 360) / 360
    }
}
