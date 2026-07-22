import Photos
import UIKit

final class PhotoLibraryService {
    private let imageManager = PHCachingImageManager()
    private let groupingWindow: TimeInterval = 180

    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func loadTimeBasedGroups() -> [PhotoGroup] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: options)
        var allAssets: [PhotoAsset] = []
        allAssets.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            allAssets.append(PhotoAsset(asset: asset))
        }

        var groups: [[PhotoAsset]] = []
        var currentGroup: [PhotoAsset] = []

        for asset in allAssets {
            guard let previous = currentGroup.last else {
                currentGroup = [asset]
                continue
            }

            if asset.creationDate.timeIntervalSince(previous.creationDate) <= groupingWindow {
                currentGroup.append(asset)
            } else {
                if currentGroup.count > 1 {
                    groups.append(currentGroup)
                }
                currentGroup = [asset]
            }
        }

        if currentGroup.count > 1 {
            groups.append(currentGroup)
        }

        return groups
            .map(PhotoGroup.init)
            .sorted { $0.endDate > $1.endDate }
    }

    func requestThumbnail(for id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let asset = fetchAsset(id: id) else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    func deleteAssets(with ids: Set<String>) async throws {
        let assets = ids.compactMap(fetchAsset)

        guard !assets.isEmpty else {
            return
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    func estimatedStorageSize(for ids: Set<String>) -> Int64 {
        ids.compactMap(fetchAsset).reduce(0) { total, asset in
            total + estimatedStorageSize(for: asset)
        }
    }

    private func estimatedStorageSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        let originalSize = resources
            .compactMap { resource in
                resource.value(forKey: "fileSize") as? NSNumber
            }
            .map(\.int64Value)
            .max()

        if let originalSize, originalSize > 0 {
            return originalSize
        }

        let pixelCount = Int64(asset.pixelWidth * asset.pixelHeight)
        return max(pixelCount / 2, 1_500_000)
    }

    private func fetchAsset(id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }
}
