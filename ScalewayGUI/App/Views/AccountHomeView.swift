import SwiftUI

struct AccountHomeView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                if !store.buckets.isEmpty {
                    bucketsSection
                } else {
                    emptyBucketsHint
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 128, height: 128)
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.accentColor)
            }

            if let account = store.selectedAccount {
                Text(account.displayName)
                    .font(.largeTitle.weight(.semibold))

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                    Text("·")
                    Text(regionLabel(for: account.signingRegion))
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Text(bucketCountText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var bucketCountText: String {
        let count = store.buckets.count
        return count == 1 ? "1 bucket available" : "\(count) buckets available"
    }

    @ViewBuilder
    private var bucketsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your Buckets")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 14)],
                spacing: 14
            ) {
                ForEach(store.buckets) { bucket in
                    BucketCard(bucket: bucket) {
                        store.selectedSidebarItem = .bucket(bucket.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyBucketsHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No buckets yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create a bucket in the Scaleway console, then refresh.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 16)
    }

    private func regionLabel(for region: String) -> String {
        switch region {
        case "nl-ams": return "NL Amsterdam"
        case "fr-par": return "FR Paris"
        case "pl-waw": return "PL Warsaw"
        default: return region
        }
    }
}

private struct BucketCard: View {
    let bucket: BucketItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                Text(bucket.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let date = bucket.createdAt {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
