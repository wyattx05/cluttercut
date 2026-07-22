import Foundation
import Photos

struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let creationDate: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let locationDescription: String?
    let isBurst: Bool

    init(asset: PHAsset) {
        id = asset.localIdentifier
        creationDate = asset.creationDate ?? .distantPast
        pixelWidth = asset.pixelWidth
        pixelHeight = asset.pixelHeight
        isBurst = asset.representsBurst

        if let location = asset.location {
            locationDescription = String(
                format: "%.3f, %.3f",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
        } else {
            locationDescription = nil
        }
    }
}
