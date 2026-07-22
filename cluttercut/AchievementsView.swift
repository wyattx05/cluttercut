import SwiftUI

struct AchievementsView: View {
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.yellow)
                    .frame(width: 78, height: 78)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())

                VStack(spacing: 8) {
                    Text("Clutter Cleared")
                        .font(.title2.weight(.bold))
                    Text("Your running total from confirmed deletes in ClutterCut.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 14) {
                    achievementCard(
                        title: "Photos Deleted",
                        value: "\(viewModel.deletedPhotoCount)",
                        systemImage: "trash"
                    )

                    achievementCard(
                        title: "Stacks Cleared",
                        value: "\(viewModel.clearedStackCount) of \(viewModel.totalStackCount)",
                        systemImage: "photo.stack"
                    )
                }

                achievementCard(
                    title: "Storage Freed",
                    value: ByteCountFormatter.string(
                        fromByteCount: viewModel.freedStorageBytes,
                        countStyle: .file
                    ),
                    systemImage: "internaldrive"
                )
                .frame(maxWidth: 260)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func achievementCard(title: String, value: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
