import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PhotoLibraryViewModel()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var isShowingReview = false
    @State private var isShowingAchievements = false
    @State private var isShowingArchivedStacks = false
    @State private var isManagingStacks = false
    @State private var selectedGroupIDs: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            GroupGridView(
                viewModel: viewModel,
                isManagingStacks: $isManagingStacks,
                selectedGroupIDs: $selectedGroupIDs
            )
                .navigationTitle("ClutterCut")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if isManagingStacks {
                            Button {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    isManagingStacks = false
                                    selectedGroupIDs.removeAll()
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .accessibilityLabel("Done selecting stacks")
                        } else {
                            Menu {
                                Button {
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                        isManagingStacks = true
                                        selectedGroupIDs.removeAll()
                                    }
                                } label: {
                                    Label("Select Stacks", systemImage: "checkmark.circle")
                                }

                                Button {
                                    isShowingArchivedStacks = true
                                } label: {
                                    Label("Archived Stacks", systemImage: "archivebox")
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                            .accessibilityLabel("Stack menu")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingAchievements = true
                        } label: {
                            Image(systemName: "trophy")
                        }
                        .accessibilityLabel("Achievements")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort Stacks", selection: $viewModel.stackSortOption) {
                                ForEach(StackSortOption.allCases) { option in
                                    Label(option.title, systemImage: option.systemImage)
                                        .tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.stackSortOption.systemImage)
                        }
                        .accessibilityLabel("Filter stacks")
                    }

                    if !viewModel.queuedAssets.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isShowingReview = true
                            } label: {
                                Text("\(viewModel.queuedAssets.count)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 32, minHeight: 30)
                                    .padding(.horizontal, 4)
                                    .background(.red, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Review \(viewModel.queuedAssets.count) queued photos")
                        }
                    }
                }
                .sheet(isPresented: $isShowingReview) {
                    ReviewDeletionView(viewModel: viewModel)
                }
                .sheet(isPresented: $isShowingAchievements) {
                    AchievementsView(viewModel: viewModel)
                }
                .sheet(isPresented: $isShowingArchivedStacks) {
                    ArchivedStacksView(viewModel: viewModel)
                }
        }
        .fullScreenCover(isPresented: welcomeBinding) {
            WelcomeView {
                hasSeenWelcome = true
            }
        }
        .task {
            await viewModel.requestAccessAndLoad()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            errorMessage = newValue
        }
        .alert("ClutterCut Needs Attention", isPresented: errorBinding) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var welcomeBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenWelcome },
            set: { isPresented in
                if !isPresented {
                    hasSeenWelcome = true
                }
            }
        )
    }
}

#Preview {
    ContentView()
}

private struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 8) {
                    Text("Welcome to ClutterCut")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Clean up similar camera roll shots without digging through your whole library.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 14) {
                welcomeRow(systemImage: "clock", title: "Finds Photo Stacks", message: "Photos taken close together are grouped into reviewable stacks.")
                welcomeRow(systemImage: "hand.draw", title: "Swipe Through Quickly", message: "Swipe or tap to keep photos, queue clutter, and move through each stack.")
                welcomeRow(systemImage: "checklist", title: "Review Before Deleting", message: "Queued photos wait for your final review before they are deleted.")
                welcomeRow(systemImage: "archivebox", title: "Archive Stacks", message: "Hide stacks from the feed and bring them back later if you need them.")
            }
            .padding(.vertical, 4)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Start Cutting Clutter")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color(.systemGroupedBackground))
    }

    private func welcomeRow(systemImage: String, title: String, message: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
