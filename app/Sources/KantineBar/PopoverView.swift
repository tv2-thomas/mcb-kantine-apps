import AppKit
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let store: MenuStore
    let hotKeys: HotKeySettings

    var body: some View {
        VStack(spacing: 0) {
            if let dish = store.openDish {
                DishDetail(dish: dish) { withAnimation(.snappy) { store.closeDish() } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    header
                    DayPicker(store: store)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    Divider()
                    content
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Divider()
            if hotKeys.isRecording {
                RecordingBar(hotKeys: hotKeys)
            } else {
                FooterBar(store: store, hotKeys: hotKeys)
            }
        }
        .frame(width: 380)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Kantina")
                    .font(.headline)
                Text(store.selectedDay.map { Format.longDate($0.date) } ?? " ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let day = store.selectedDay, !day.dishes.isEmpty {
            FittedScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(day.dishes.enumerated()), id: \.element.id) { index, dish in
                        DishRow(dish: dish, number: index < 9 ? index + 1 : nil) {
                            withAnimation(.snappy) { store.openDish(dish.id) }
                        }
                    }
                }
                .padding(8)
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            if store.error != nil {
                Text("🥲").font(.largeTitle)
                Text(store.error ?? "").foregroundStyle(.secondary)
                Button("Prøv igjen") { Task { await store.refresh() } }
            } else if store.isLoading {
                ProgressView()
            } else {
                Text("😴").font(.largeTitle)
                Text("Ingen meny denne dagen").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}

struct FittedScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .frame(height: min(max(contentHeight, 1), 520))
    }
}

private struct DayPicker: View {
    let store: MenuStore
    @State private var position = ScrollPosition(idType: String.self)
    @State private var offset: CGFloat = 0
    @State private var maxOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat?
    @State private var suppressTap = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal) { chips.scrollTargetLayout() }
                .scrollIndicators(.never)
                .scrollPosition($position, anchor: .center)
                .onScrollGeometryChange(for: [CGFloat].self) { geometry in
                    [geometry.contentOffset.x, geometry.contentSize.width - geometry.containerSize.width]
                } action: { _, values in
                    offset = values[0]
                    maxOffset = max(values[1], 0)
                }
                .simultaneousGesture(drag)
                .onAppear { centerSelected() }
                .onChange(of: store.selectedID) { withAnimation(.snappy) { centerSelected() } }
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(store.days) { day in
                DayChip(
                    day: day,
                    isToday: day.id == store.todayKey,
                    isSelected: day.id == store.selectedDay?.id
                ) {
                    if !suppressTap { store.select(day.id) }
                }
                .frame(minWidth: 44)
                .id(day.id)
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let start = dragStartOffset ?? offset
                dragStartOffset = start
                suppressTap = true
                position.scrollTo(x: min(max(start - value.translation.width, 0), maxOffset))
            }
            .onEnded { _ in
                dragStartOffset = nil
                Task { @MainActor in suppressTap = false } // the chip under the pointer gets its click after the drag ends
            }
    }

    private func centerSelected() {
        if let id = store.selectedDay?.id { position.scrollTo(id: id, anchor: .center) }
    }
}

private struct DayChip: View {
    let day: Day
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(Format.weekday(day.date))
                    .font(.caption2.weight(.medium))
                    .textCase(.uppercase)
                Text(Format.dayNumber(day.date))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Circle()
                    .frame(width: 4, height: 4)
                    .opacity(isToday ? 1 : 0)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor) }
        return AnyShapeStyle(.quaternary.opacity(isHovered ? 1 : 0.5))
    }
}

private struct FooterBar: View {
    let store: MenuStore
    let hotKeys: HotKeySettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(LunchNudge.enabledKey) private var lunchNudge = true
    @AppStorage(LunchNudge.minuteOfDayKey) private var lunchMinuteOfDay = LunchNudge.defaultMinuteOfDay

    var body: some View {
        HStack(spacing: 14) {
            Button { Task { await store.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Oppdater")
            .disabled(store.isLoading)

            Button { NSWorkspace.shared.open(MenuAPI.site) } label: {
                Image(systemName: "safari")
            }
            .help("Åpne i nettleseren")

            Spacer()

            Menu {
                Section("Hurtigtast: \(hotKeys.shortcut?.display ?? "ingen")") {
                    Button(hotKeys.shortcut == nil ? "Velg hurtigtast…" : "Endre hurtigtast…") { hotKeys.startRecording() }
                    if hotKeys.shortcut != nil {
                        Button("Fjern hurtigtast") { hotKeys.clear() }
                    }
                }
                Divider()
                Menu("Lunsjpåminnelse: \(lunchNudge ? LunchNudge.format(lunchMinuteOfDay) : "av")") {
                    Toggle("På", isOn: $lunchNudge)
                    Picker("Tidspunkt", selection: $lunchMinuteOfDay) {
                        ForEach(LunchNudge.choices, id: \.self) { Text(LunchNudge.format($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .disabled(!lunchNudge)
                }
                Toggle("Start ved innlogging", isOn: $launchAtLogin)
                Divider()
                Button("Avslutt Kantine Bar") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Mer")
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

private struct RecordingBar: View {
    let hotKeys: HotKeySettings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .foregroundStyle(Color.accentColor)
            Text(hotKeys.recordingHint ?? "Trykk ny hurtigtast")
                .font(.callout)
                .foregroundStyle(hotKeys.recordingHint == nil ? .primary : .secondary)
                .contentTransition(.opacity)
            Spacer()
            Button("Avbryt") { hotKeys.cancelRecording() }
                .buttonStyle(.borderless)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .animation(.snappy, value: hotKeys.recordingHint)
    }
}

enum Format {
    private static let norwegian = Locale(identifier: "nb_NO")

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(norwegian))
            .trimmingCharacters(in: .punctuationCharacters)
    }

    static func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(norwegian))
            .trimmingCharacters(in: .punctuationCharacters)
    }

    static func longDate(_ date: Date) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(norwegian))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static func co2(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(1)).locale(norwegian))
    }
}
