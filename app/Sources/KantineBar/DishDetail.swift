import SwiftUI

struct DishDetail: View {
    let dish: Dish
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("Tilbake", systemImage: "chevron.left")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()
            FittedScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    VStack(alignment: .leading, spacing: 4) {
                        CategoryLabel(category: dish.category)
                        Text(dish.name)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if !dish.description.isEmpty {
                            Text(dish.description)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        DishFacts(dish: dish, showsAllergens: false)
                            .font(.caption)
                            .padding(.top, 2)
                    }
                    if !dish.allergens.isEmpty {
                        section("Allergener") {
                            Text(dish.allergens)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !dish.nutrients.isEmpty {
                        section("Næringsinnhold per 100 g") { nutrients }
                    }
                }
                .padding(16)
                .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let image = dish.image {
            Color.clear
                .frame(height: 210)
                .overlay { Image(nsImage: image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        } else {
            HStack {
                Spacer()
                Thumbnail(dish: dish, size: 96)
                Spacer()
            }
        }
    }

    private var nutrients: some View {
        VStack(spacing: 0) {
            ForEach(dish.nutrients) { nutrient in
                HStack {
                    Text(nutrient.name)
                        .foregroundStyle(nutrient.isSubItem ? .secondary : .primary)
                        .padding(.leading, nutrient.isSubItem ? 12 : 0)
                    Spacer(minLength: 12)
                    Text(nutrient.value)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(nutrient.isSubItem ? .caption : .callout)
                .padding(.vertical, 4)
                if nutrient.id != dish.nutrients.last?.id {
                    Divider().opacity(0.5)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }
}
