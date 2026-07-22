import Combine
import Photos
import SwiftUI
import UIKit

enum StackSortOption: String, CaseIterable, Identifiable {
    case date
    case mostPhotos
    case leastPhotos

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .date:
            return "Date"
        case .mostPhotos:
            return "Most Photos"
        case .leastPhotos:
            return "Least Photos"
        }
    }

    var systemImage: String {
        switch self {
        case .date:
            return "calendar"
        case .mostPhotos:
            return "arrow.down.circle"
        case .leastPhotos:
            return "arrow.up.circle"
        }
    }
}

@MainActor
final class PhotoLibraryViewModel: ObservableObject {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus
    @Published private(set) var groups: [PhotoGroup] = []
    @Published private(set) var archivedGroups: [PhotoGroup] = []
    @Published private(set) var thumbnails: [String: UIImage] = [:]
    @Published private(set) var queuedAssets: Set<String> = []
    @Published private(set) var removedGroupIDs: Set<String> = []
    @Published private(set) var deletedPhotoCount = 0
    @Published private(set) var clearedStackCount = 0
    @Published private(set) var freedStorageBytes: Int64 = 0
    @Published var stackSortOption: StackSortOption = .date
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = PhotoLibraryService()
    private let deletedPhotoCountKey = "deletedPhotoCount"
    private let clearedStackCountKey = "clearedStackCount"
    private let freedStorageBytesKey = "freedStorageBytes"
    private let archivedGroupIDsKey = "archivedGroupIDs"

    init() {
        authorizationStatus = service.authorizationStatus()
        deletedPhotoCount = UserDefaults.standard.integer(forKey: deletedPhotoCountKey)
        clearedStackCount = UserDefaults.standard.integer(forKey: clearedStackCountKey)
        freedStorageBytes = Int64(UserDefaults.standard.integer(forKey: freedStorageBytesKey))
        removedGroupIDs = Set(UserDefaults.standard.stringArray(forKey: archivedGroupIDsKey) ?? [])
    }

    var sortedGroups: [PhotoGroup] {
        switch stackSortOption {
        case .date:
            return groups.sorted { $0.endDate > $1.endDate }
        case .mostPhotos:
            return groups.sorted {
                if $0.assets.count == $1.assets.count {
                    return $0.endDate > $1.endDate
                }

                return $0.assets.count > $1.assets.count
            }
        case .leastPhotos:
            return groups.sorted {
                if $0.assets.count == $1.assets.count {
                    return $0.endDate > $1.endDate
                }

                return $0.assets.count < $1.assets.count
            }
        }
    }

    var totalStackCount: Int {
        clearedStackCount + groups.count + archivedGroups.count
    }

    func requestAccessAndLoad() async {
        let status = service.authorizationStatus()

        switch status {
        case .authorized, .limited:
            authorizationStatus = status
            await loadGroups()
        case .notDetermined:
            let requestedStatus = await service.requestAuthorization()
            authorizationStatus = requestedStatus
            if requestedStatus == .authorized || requestedStatus == .limited {
                await loadGroups()
            }
        default:
            authorizationStatus = status
        }
    }

    func loadGroups() async {
        isLoading = true
        errorMessage = nil

        let loadedGroups = service.loadTimeBasedGroups()

        archivedGroups = loadedGroups
            .filter { removedGroupIDs.contains($0.id) }
        groups = loadedGroups
            .filter { !removedGroupIDs.contains($0.id) }
        isLoading = false
        warmVisibleThumbnails()
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    func queue(_ asset: PhotoAsset) {
        queuedAssets.insert(asset.id)
    }

    func queue(_ assets: [PhotoAsset]) {
        queuedAssets.formUnion(assets.map(\.id))
    }

    func unqueue(_ asset: PhotoAsset) {
        queuedAssets.remove(asset.id)
    }

    func toggleQueue(_ asset: PhotoAsset) {
        if queuedAssets.contains(asset.id) {
            unqueue(asset)
        } else {
            queue(asset)
        }
    }

    func isQueued(_ asset: PhotoAsset) -> Bool {
        queuedAssets.contains(asset.id)
    }

    func queuedAssetsInGroup(_ group: PhotoGroup) -> Int {
        group.assets.filter { queuedAssets.contains($0.id) }.count
    }

    func removeGroup(_ group: PhotoGroup) {
        archiveGroups([group])
    }

    func archiveGroups(_ groupsToArchive: [PhotoGroup]) {
        guard !groupsToArchive.isEmpty else {
            return
        }

        for group in groupsToArchive {
            removedGroupIDs.insert(group.id)
            queuedAssets.subtract(group.assets.map(\.id))
            if !archivedGroups.contains(where: { $0.id == group.id }) {
                archivedGroups.append(group)
            }
        }

        groups.removeAll { removedGroupIDs.contains($0.id) }
        archivedGroups.sort { $0.endDate > $1.endDate }
        persistArchivedGroupIDs()
    }

    func restoreArchivedGroups(_ groupsToRestore: [PhotoGroup]) {
        guard !groupsToRestore.isEmpty else {
            return
        }

        let ids = Set(groupsToRestore.map(\.id))
        removedGroupIDs.subtract(ids)
        archivedGroups.removeAll { ids.contains($0.id) }

        for group in groupsToRestore where !groups.contains(where: { $0.id == group.id }) {
            groups.append(group)
        }

        groups.sort { $0.endDate > $1.endDate }
        persistArchivedGroupIDs()
    }

    func groups(withIDs ids: Set<String>, includeArchived: Bool = false) -> [PhotoGroup] {
        let source = includeArchived ? groups + archivedGroups : groups
        return source.filter { ids.contains($0.id) }
    }

    func thumbnail(for asset: PhotoAsset, size: CGSize = CGSize(width: 360, height: 360)) -> UIImage? {
        if let cached = thumbnails[asset.id] {
            return cached
        }

        service.requestThumbnail(for: asset.id, targetSize: size) { [weak self] image in
            Task { @MainActor in
                self?.thumbnails[asset.id] = image
            }
        }

        return nil
    }

    func deleteQueuedAssets() async {
        guard !queuedAssets.isEmpty else {
            return
        }

        await deleteAssets(withIDs: queuedAssets, clearQueuedAssets: true)
    }

    func deleteAssets(_ assets: [PhotoAsset]) {
        queue(assets)
    }

    func deleteGroups(_ groupsToDelete: [PhotoGroup]) {
        queue(groupsToDelete.flatMap(\.assets))
    }

    private func deleteAssets(withIDs ids: Set<String>, clearQueuedAssets: Bool) async {
        isLoading = true
        errorMessage = nil
        let deletedCount = ids.count
        let storageSize = service.estimatedStorageSize(for: ids)
        let clearedStacks = (groups + archivedGroups)
            .filter { group in
                group.assets.allSatisfy { ids.contains($0.id) }
            }
            .count

        do {
            try await service.deleteAssets(with: ids)
            groups = groups.compactMap { group in
                let remainingAssets = group.assets.filter { !ids.contains($0.id) }
                return remainingAssets.count > 1 ? PhotoGroup(assets: remainingAssets) : nil
            }
            archivedGroups = archivedGroups.compactMap { group in
                let remainingAssets = group.assets.filter { !ids.contains($0.id) }
                return remainingAssets.count > 1 ? PhotoGroup(assets: remainingAssets) : nil
            }
            removedGroupIDs = Set(archivedGroups.map(\.id))
            recordDeletedPhotos(count: deletedCount, clearedStacks: clearedStacks, storageSize: storageSize)
            queuedAssets.subtract(ids)
            if clearQueuedAssets {
                queuedAssets.removeAll()
            }
            persistArchivedGroupIDs()
        } catch {
            errorMessage = "Could not delete photos. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func recordDeletedPhotos(count: Int, clearedStacks: Int, storageSize: Int64) {
        deletedPhotoCount += count
        clearedStackCount += clearedStacks
        freedStorageBytes += storageSize
        UserDefaults.standard.set(deletedPhotoCount, forKey: deletedPhotoCountKey)
        UserDefaults.standard.set(clearedStackCount, forKey: clearedStackCountKey)
        UserDefaults.standard.set(Int(freedStorageBytes), forKey: freedStorageBytesKey)
    }

    private func persistArchivedGroupIDs() {
        UserDefaults.standard.set(Array(removedGroupIDs), forKey: archivedGroupIDsKey)
    }

    private func warmVisibleThumbnails() {
        for group in groups.prefix(24) {
            for asset in group.assets.prefix(4) {
                _ = thumbnail(for: asset)
            }
        }
    }
}
