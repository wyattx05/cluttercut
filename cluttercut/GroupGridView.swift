import Photos
import SwiftUI

struct GroupGridView: View {
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @Binding var isManagingStacks: Bool
    @Binding var selectedGroupIDs: Set<String>

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            content

            if isManagingStacks {
                stackSelectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isManagingStacks)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: selectedGroupIDs)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.authorizationStatus {
        case .authorized, .limited:
            if viewModel.isLoading && viewModel.groups.isEmpty {
                ProgressView("Scanning photos")
            } else if viewModel.groups.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "No Similar Sets",
                    message: "ClutterCut did not find photo groups taken within three minutes of each other."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.sortedGroups) { group in
                            if isManagingStacks {
                                Button {
                                    toggleSelection(group)
                                } label: {
                                    PhotoGroupTile(
                                        group: group,
                                        viewModel: viewModel,
                                        isSelectionMode: true,
                                        isSelected: selectedGroupIDs.contains(group.id)
                                    )
                                }
                                .buttonStyle(StackNavigationButtonStyle())
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.22)
                                        .onEnded { _ in
                                            toggleSelection(group)
                                        }
                                )
                            } else {
                                NavigationLink {
                                    PhotoGroupReviewView(group: group, viewModel: viewModel)
                                } label: {
                                    PhotoGroupTile(group: group, viewModel: viewModel)
                                }
                                .buttonStyle(StackNavigationButtonStyle())
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
                .refreshable {
                    await viewModel.loadGroups()
                }
            }
        case .notDetermined:
            ProgressView("Preparing library access")
        default:
            VStack(spacing: 18) {
                EmptyStateView(
                    systemImage: "photo.stack",
                    title: "Photo Access Needed",
                    message: "Allow photo access in Settings so ClutterCut can find similar camera roll sets."
                )

                Button {
                    viewModel.openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }

    private var stackSelectionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Button {
                    selectedGroupIDs.removeAll()
                } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 18)
                        .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Clear selected stacks")

                Button {
                    let selectedGroups = viewModel.groups(withIDs: selectedGroupIDs)
                    viewModel.archiveGroups(selectedGroups)
                    selectedGroupIDs.removeAll()
                    isManagingStacks = false
                } label: {
                    Label("Archive \(selectedGroupIDs.count)", systemImage: "archivebox")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 20)
                        .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Archive selected stacks")

                Button(role: .destructive) {
                    let selectedGroups = viewModel.groups(withIDs: selectedGroupIDs)
                    viewModel.deleteGroups(selectedGroups)
                    selectedGroupIDs.removeAll()
                    isManagingStacks = false
                } label: {
                    Label("Review \(selectedGroupIDs.count)", systemImage: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 20)
                        .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty || viewModel.isLoading)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Add selected stacks to review")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 30)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func toggleSelection(_ group: PhotoGroup) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
    }
}

private struct PhotoGroupTile: View {
    let group: PhotoGroup
    @ObservedObject var viewModel: PhotoLibraryViewModel
    var isSelectionMode = false
    var isSelected = false
    @Environment(\.colorScheme) private var colorScheme

    private var queuedCount: Int {
        viewModel.queuedAssetsInGroup(group)
    }

    private var tileBackground: Color {
        colorScheme == .dark ? Color(white: 0.17) : Color(.systemBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoStackPreview(group: group, viewModel: viewModel)
                .overlay(alignment: .topTrailing) {
                    Text("\(group.assets.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(group.endDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 7) {
                    Label("\(Int(group.timeSpan / 60) + 1)m", systemImage: "clock")
                    if group.hasLocationData {
                        Image(systemName: "location")
                    }
                    if group.hasBurstPhotos {
                        Image(systemName: "bolt")
                    }
                    Spacer(minLength: 0)
                    if queuedCount > 0 {
                        Text("\(queuedCount) queued")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected ? Color.primary.opacity(0.55) : (colorScheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.06)),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .topLeading) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                    .padding(10)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeGroup(group)
            } label: {
                Label("Archive Stack", systemImage: "archivebox")
            }
        }
    }
}

struct ArchivedStacksView: View {
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroupIDs: Set<String> = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.archivedGroups.isEmpty {
                    EmptyStateView(
                        systemImage: "archivebox",
                        title: "No Archived Stacks",
                        message: "Stacks you archive from the main feed will show up here."
                    )
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(viewModel.archivedGroups) { group in
                                Button {
                                    toggleSelection(group)
                                } label: {
                                    PhotoGroupTile(
                                        group: group,
                                        viewModel: viewModel,
                                        isSelectionMode: true,
                                        isSelected: selectedGroupIDs.contains(group.id)
                                    )
                                }
                                .buttonStyle(StackNavigationButtonStyle())
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 92)
                    }
                }

                if !viewModel.archivedGroups.isEmpty {
                    archiveActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Archived")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var archiveActionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Button {
                    selectedGroupIDs.removeAll()
                } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 18)
                        .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)

                Button {
                    let selectedGroups = viewModel.groups(withIDs: selectedGroupIDs, includeArchived: true)
                    viewModel.restoreArchivedGroups(selectedGroups)
                    selectedGroupIDs.removeAll()
                } label: {
                    Label("Restore \(selectedGroupIDs.count)", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 20)
                        .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Restore selected stacks")

                Button(role: .destructive) {
                    let selectedGroups = viewModel.groups(withIDs: selectedGroupIDs, includeArchived: true)
                    viewModel.deleteGroups(selectedGroups)
                    selectedGroupIDs.removeAll()
                } label: {
                    Label("Review \(selectedGroupIDs.count)", systemImage: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(height: 46)
                        .padding(.horizontal, 20)
                        .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedGroupIDs.isEmpty || viewModel.isLoading)
                .opacity(selectedGroupIDs.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Add selected archived stacks to review")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 30)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func toggleSelection(_ group: PhotoGroup) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
    }
}

private struct PhotoStackPreview: View {
    let group: PhotoGroup
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let cardSize = max(0, size - 18)

            ZStack(alignment: .bottomLeading) {
                stackCard(size: cardSize, offset: CGSize(width: 10, height: -10), rotation: 3.2, opacity: 0.58, assetIndex: 2)
                stackCard(size: cardSize, offset: CGSize(width: 5, height: -5), rotation: 1.6, opacity: 0.80, assetIndex: 1)
                stackCard(size: cardSize, offset: .zero, rotation: 0, opacity: 1, assetIndex: 0)
            }
            .frame(width: size, height: size, alignment: .bottomLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
    }

	    private func stackCard(size: CGFloat, offset: CGSize, rotation: Double, opacity: Double, assetIndex: Int) -> some View {
	        let cardBackground = colorScheme == .dark ? Color(white: 0.20) : Color(.secondarySystemBackground)
	        let strokeColor = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)

	        return ZStack {
	            if group.assets.indices.contains(assetIndex) {
	                PhotoThumbnail(
	                    asset: group.assets[assetIndex],
	                    viewModel: viewModel,
	                    cornerRadius: 12,
	                    contentMode: .fill,
	                    borderColor: .clear,
	                    borderWidth: 0
	                )
	            } else {
	                RoundedRectangle(cornerRadius: 12, style: .continuous)
	                    .fill(cardBackground)
	            }
	        }
	        .frame(width: size, height: size)
	        .clipped()
	        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	        .brightness(colorScheme == .dark ? 0.025 : 0)
	        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	        .overlay {
	            RoundedRectangle(cornerRadius: 12, style: .continuous)
	                .stroke(strokeColor, lineWidth: 1)
	        }
	        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.12), radius: 5, x: 0, y: 3)
	        .opacity(opacity)
	        .rotationEffect(.degrees(rotation))
	        .offset(offset)
	    }
	}

private struct StackNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

struct PhotoThumbnail: View {
    let asset: PhotoAsset
    @ObservedObject var viewModel: PhotoLibraryViewModel
    var cornerRadius: CGFloat = 0
    var contentMode: ContentMode = .fill
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0

    var body: some View {
        Group {
            if let image = viewModel.thumbnail(for: asset) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.35))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary.opacity(0.45))
                    }
            }
	        }
	        .frame(maxWidth: .infinity, maxHeight: .infinity)
	        .clipped()
	        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        }
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 360)
    }
}
