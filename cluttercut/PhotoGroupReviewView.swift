import SwiftUI

struct PhotoGroupReviewView: View {
    let group: PhotoGroup
    @ObservedObject var viewModel: PhotoLibraryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isAdvancing = false
    @State private var isShowingGroupGrid = false
    @State private var isHoldingPhoto = false
    @State private var isSelectionMode = false
    @State private var selectedAssetIDs: Set<String> = []
    @State private var isConfirmingBulkDelete = false

    private var currentAsset: PhotoAsset? {
        guard group.assets.indices.contains(currentIndex) else {
            return nil
        }
        return group.assets[currentIndex]
    }

    private var isChromeHidden: Bool {
        (isHoldingPhoto || isAdvancing) && !isShowingGroupGrid
    }

    private var selectedAssets: [PhotoAsset] {
        group.assets.filter { selectedAssetIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if isShowingGroupGrid {
                groupThumbnailGrid
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else if let asset = currentAsset {
                photoViewer(asset)
                    .id(asset.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985)),
                        removal: .opacity.combined(with: .scale(scale: 1.015))
                    ))
            } else {
                completionState
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if !isChromeHidden {
                overlayChrome
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.18), value: isChromeHidden)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isShowingGroupGrid)
        .animation(.spring(response: 0.30, dampingFraction: 0.9), value: currentIndex)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: selectedAssetIDs)
        .alert("Add selected photos to Review?", isPresented: $isConfirmingBulkDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Add to Review", role: .destructive) {
                let assets = selectedAssets
                viewModel.deleteAssets(assets)
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    selectedAssetIDs.removeAll()
                    isSelectionMode = false
                }
            }
        } message: {
            Text("These photos will stay in your library until you confirm deletion from Review.")
        }
    }

    private func photoViewer(_ asset: PhotoAsset) -> some View {
        PhotoThumbnail(asset: asset, viewModel: viewModel, contentMode: .fit)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 42)))
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: dragOffset)
            .gesture(dragGesture)
            .onLongPressGesture(
                minimumDuration: 0.12,
                maximumDistance: 24,
                pressing: { isPressing in
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isHoldingPhoto = isPressing
                    }
                },
                perform: {}
            )
            .overlay {
                swipeHint
            }
    }

    private var overlayChrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if !isShowingGroupGrid {
                bottomControls
            } else if isSelectionMode {
                selectionControls
            } else {
                groupSelectFloatingButton
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var topBar: some View {
        ZStack {
            HStack {
                backButton
                Spacer()
                rightControls
            }

            titleCapsule
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var rightControls: some View {
        modeButton
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
        }
        .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Circle())
        .shadow(color: .black.opacity(0.32), radius: 10, x: 0, y: 6)
        .accessibilityLabel("Back")
    }

    private var modeButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                if isShowingGroupGrid && isSelectionMode {
                    selectedAssetIDs.removeAll()
                    isSelectionMode = false
                } else {
                    isShowingGroupGrid.toggle()
                    dragOffset = .zero
                    selectedAssetIDs.removeAll()
                    isSelectionMode = false
                }
            }
        } label: {
            Image(systemName: modeButtonIcon)
                .font(.system(size: modeButtonFontSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
        }
        .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Circle())
        .shadow(color: .black.opacity(0.32), radius: 10, x: 0, y: 6)
        .accessibilityLabel(modeButtonAccessibilityLabel)
    }

    private var modeButtonIcon: String {
        if isShowingGroupGrid && isSelectionMode {
            return "checkmark.circle.fill"
        }

        return isShowingGroupGrid ? "rectangle.portrait" : "square.grid.2x2"
    }

    private var modeButtonFontSize: CGFloat {
        if isShowingGroupGrid && isSelectionMode {
            return 20
        }

        return isShowingGroupGrid ? 18 : 22
    }

    private var modeButtonAccessibilityLabel: String {
        if isShowingGroupGrid && isSelectionMode {
            return "Done selecting photos"
        }

        return isShowingGroupGrid ? "Show swipe view" : "Show all photos in group"
    }

    private var selectButton: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedAssetIDs.removeAll()
                }
            }
        } label: {
            Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
        .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Circle())
        .shadow(color: .black.opacity(0.32), radius: 10, x: 0, y: 6)
        .accessibilityLabel(isSelectionMode ? "Done selecting" : "Select photos")
    }

    private var titleCapsule: some View {
        VStack(spacing: 2) {
            Text(topTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(topSubtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 20)
        .frame(minWidth: 146, maxWidth: 190, minHeight: 50)
        .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: Capsule())
        .shadow(color: .black.opacity(0.32), radius: 10, x: 0, y: 6)
    }

    private var topTitle: String {
        if isShowingGroupGrid {
            if isSelectionMode {
                return selectedAssetIDs.isEmpty ? "Select Photos" : "\(selectedAssetIDs.count) Selected"
            }
            return "All Photos"
        }

        return currentAsset?.creationDate.formatted(date: .abbreviated, time: .omitted) ?? ""
    }

    private var topSubtitle: String {
        if isShowingGroupGrid {
            if isSelectionMode {
                return selectedAssetIDs.isEmpty ? "Tap photos to choose" : "Add to Review"
            }
            return "\(group.assets.count) photos in this stack"
        }

        let position = min(currentIndex + 1, group.assets.count)
        let time = currentAsset?.creationDate.formatted(date: .omitted, time: .shortened) ?? ""
        return "Photo \(position) of \(group.assets.count)  \(time)"
    }

    private var bottomControls: some View {
        HStack(spacing: 30) {
            if let asset = currentAsset {
                Button {
                    let wasQueued = viewModel.isQueued(asset)
                    advance()

                    if wasQueued {
                        viewModel.unqueue(asset)
                    } else {
                        viewModel.queue(asset)
                    }
                } label: {
                    swipeActionButton(
                        systemImage: viewModel.isQueued(asset) ? "arrow.uturn.left" : "trash",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isQueued(asset) ? "Undo delete" : "Delete photo")

                Button {
                    advance()
                } label: {
                    swipeActionButton(systemImage: "checkmark", tint: .green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Keep photo")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectionControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    selectedAssetIDs.removeAll()
                }
            } label: {
                Text("Clear")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(height: 46)
                    .padding(.horizontal, 18)
                    .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedAssetIDs.isEmpty)
            .opacity(selectedAssetIDs.isEmpty ? 0.45 : 1)

            Button {
                isConfirmingBulkDelete = true
            } label: {
                Label("Review \(selectedAssetIDs.count)", systemImage: "trash")
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
            .disabled(selectedAssetIDs.isEmpty || viewModel.isLoading)
            .opacity(selectedAssetIDs.isEmpty ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var groupSelectFloatingButton: some View {
        HStack {
            Spacer()
            selectButton
        }
        .padding(.trailing, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func swipeActionButton(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 62, height: 62)
            .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.32), lineWidth: 0.75)
            }
            .shadow(color: tint.opacity(0.20), radius: 14, x: 0, y: 8)
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
    }

    private var groupThumbnailGrid: some View {
        GeometryReader { proxy in
            let horizontalPadding = max(32, proxy.size.width * 0.09)
            let columnSpacing = max(14, proxy.size.width * 0.06)
            let tileWidth = max(118, (proxy.size.width - (horizontalPadding * 2) - columnSpacing) / 2)
            let tileHeight = tileWidth
            let columns = [
                GridItem(.fixed(tileWidth), spacing: columnSpacing),
                GridItem(.fixed(tileWidth), spacing: columnSpacing)
            ]

            ScrollView {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(Array(group.assets.enumerated()), id: \.element.id) { index, asset in
                        Button {
                            if isSelectionMode {
                                toggleSelection(asset)
                            } else {
                                currentIndex = index
                                dragOffset = .zero
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    isShowingGroupGrid = false
                                }
                            }
                        } label: {
                            groupThumbnailTile(asset: asset, index: index, width: tileWidth, height: tileHeight)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.22)
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                        isSelectionMode = true
                                        selectedAssetIDs.insert(asset.id)
                                    }
                                }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 184)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity)
            }
            .background(Color.black)
        }
    }

    private func groupThumbnailTile(asset: PhotoAsset, index: Int, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = selectedAssetIDs.contains(asset.id)

        return PhotoThumbnail(asset: asset, viewModel: viewModel, cornerRadius: 18)
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if isSelectionMode {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? .white.opacity(0.12) : .black.opacity(0.18))
                }
            }
            .overlay(alignment: .topLeading) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 2)
                        .padding(8)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isQueued(asset) {
                    Image(systemName: "trash.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.22), lineWidth: 1)
                        }
                        .padding(7)
                    }
            }
            .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 6)
            .scaleEffect(isSelected ? 0.965 : 1)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isAdvancing else {
                    return
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                handleSwipe(value)
            }
    }

    @ViewBuilder
    private var swipeHint: some View {
        if abs(dragOffset.width) > 35 {
            let isDeleting = dragOffset.width < 0
            Image(systemName: isDeleting ? "xmark" : "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .glassEffect(.regular.tint(.white.opacity(0.18)).interactive(), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.26), lineWidth: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isDeleting ? .center : .center)
                .opacity(min(0.94, 0.35 + abs(dragOffset.width) / 220))
                .scaleEffect(min(1.08, 0.92 + abs(dragOffset.width) / 520))
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: dragOffset)
        }
    }

    private var completionState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.green)
            Text("Set Reviewed")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Open Review when you are ready to permanently delete queued photos.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Back to Stacks") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let width = value.translation.width
        let predictedWidth = value.predictedEndTranslation.width
        let shouldDelete = width < -90 || predictedWidth < -150
        let shouldKeep = width > 90 || predictedWidth > 150

        if shouldDelete, let asset = currentAsset {
            viewModel.queue(asset)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                dragOffset = CGSize(width: -520, height: value.translation.height * 0.35)
            }
            advanceAfterAnimation()
        } else if shouldKeep {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                dragOffset = CGSize(width: 520, height: value.translation.height * 0.35)
            }
            advanceAfterAnimation()
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                dragOffset = .zero
            }
        }
    }

    private func toggleSelection(_ asset: PhotoAsset) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            if selectedAssetIDs.contains(asset.id) {
                selectedAssetIDs.remove(asset.id)
            } else {
                selectedAssetIDs.insert(asset.id)
            }
        }
    }

    private func advanceAfterAnimation() {
        isAdvancing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            advance()
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            isAdvancing = false
            dragOffset = .zero
            currentIndex = min(currentIndex + 1, group.assets.count)
        }
    }

}
