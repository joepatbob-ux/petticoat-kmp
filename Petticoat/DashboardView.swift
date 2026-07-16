import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DashboardThermostatCard()

                SpotlightSection(item: model.spotlight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SensiWordmark(color: SMA.labelPrimary, size: 26)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "plus")
                }
                Button {} label: {
                    Image(systemName: "questionmark.bubble")
                }
                Button { model.showAccount = true } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
    }
}

// MARK: - Thermostat card

struct DashboardThermostatCard: View {
    @Environment(AppModel.self) private var model

    private var device: Device { model.device }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                DeviceTabView()
            } label: {
                HStack {
                    Text(device.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                ModeSelectPill(axis: .vertical)

                Text("\(device.currentTemp)")
                    .font(SMA.displayTemp(size: 46, activity: device.activity))
                    .foregroundStyle(SMA.tempColor(device.activity))

                Spacer(minLength: 8)

                SetpointStepper(low: device.keepMin, high: device.keepMax) { bound, delta in
                    model.adjustKeep(bound, by: delta)
                }
            }
            .padding(16)
            .cardStyle(cornerRadius: 20)

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text("Until \(device.holdUntil)")
            }
            .font(.footnote)
            .foregroundStyle(SMA.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Spotlight

struct SpotlightSection: View {
    let item: SpotlightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spotlight")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SMA.labelPrimary)
                Spacer()
                Text("1")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(SMA.accent, in: Circle())
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.accent)
            }

            SpotlightCard(item: item)
        }
    }
}

private struct SpotlightCard: View {
    let item: SpotlightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(SMA.orange)
                Text(item.provider)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SMA.brandNavy)
            }

            Text(item.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)

            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(SMA.labelSecondary)

            Text("Offer valid until: \(item.validUntil)")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary.opacity(0.8))

            Divider().overlay(SMA.separator)

            HStack {
                Text("Learn More")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(SMA.orange, in: Capsule())
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SMA.accent)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(SMA.accent, lineWidth: 1.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(AppModel())
}
