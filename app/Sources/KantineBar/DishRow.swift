import SwiftUI

struct DishRow: View {
    let dish: Dish
    let number: Int?
    let onOpen: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Thumbnail(dish: dish, size: 54)
                    .overlay(alignment: .topLeading) {
                        if let number {
                            NumberBadge(number: number, color: DishStyle.badge(for: dish.category))
                                .offset(x: -5, y: -5)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    CategoryLabel(category: dish.category)
                    Text(dish.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dish.description.isEmpty {
                        Text(dish.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    DishFacts(dish: dish, showsAllergens: true)
                        .padding(.top, 1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(.quaternary.opacity(isHovered ? 0.6 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct CategoryLabel: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(DishStyle.tint(for: category))
    }
}

struct DishFacts: View {
    let dish: Dish
    let showsAllergens: Bool

    var body: some View {
        HStack(spacing: 10) {
            if dish.kcal > 0 {
                Label("\(dish.kcal) kcal", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
            }
            if dish.co2 > 0 {
                Label("\(Format.co2(dish.co2)) kg CO₂", systemImage: "leaf.fill")
                    .foregroundStyle(.green)
            }
            if showsAllergens, !dish.allergens.isEmpty {
                Text(dish.allergens)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.caption2)
        .labelStyle(CompactLabelStyle())
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title.foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

struct Thumbnail: View {
    let dish: Dish
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            if let image = dish.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                let tint = DishStyle.tint(for: dish.category)
                LinearGradient(
                    colors: [tint.opacity(0.35), tint.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(DishStyle.emoji(for: dish))
                    .font(.system(size: size * 0.48))
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.08)))
    }
}

private struct NumberBadge: View {
    let number: Int
    let color: Color

    var body: some View {
        Text("\(number)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
    }
}
