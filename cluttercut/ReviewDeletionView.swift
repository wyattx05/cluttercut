import SwiftUI

struct ReviewDeletionView: View {
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    private var queuedAssets: [PhotoAsset] {
        (viewModel.groups + viewModel.archivedGroups)
            .flatMap(\.assets)
            .filter { viewModel.queuedAssets.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if queuedAssets.isEmpty {
                    ContentUnavailableView(
                        "No Photos Queued",
                        systemImage: "trash",
                        description: Text("Swipe left or use a Delete button to add photos here first.")
                    )
                } else {
                    Section {
                        ForEach(queuedAssets) { asset in
                            HStack(spacing: 12) {
                                PhotoThumbnail(asset: asset, viewModel: viewModel, cornerRadius: 6)
                                    .frame(width: 58, height: 58)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(asset.creationDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(asset.pixelWidth) x \(asset.pixelHeight)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.unqueue(asset)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Remove from deletion queue")
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("Photos are not deleted until you confirm here.")
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Text("Delete \(queuedAssets.count)")
                    }
                    .disabled(queuedAssets.isEmpty || viewModel.isLoading)
                }
            }
            .alert("Delete queued photos?", isPresented: $isConfirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteQueuedAssets()
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This moves \(queuedAssets.count) photos to Recently Deleted.")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Updating Library")
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
