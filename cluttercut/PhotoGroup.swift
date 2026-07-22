import Foundation

struct PhotoGroup: Identifiable, Hashable {
    let id: String
    let assets: [PhotoAsset]

    var startDate: Date {
        assets.first?.creationDate ?? .distantPast
    }

    var endDate: Date {
        assets.last?.creationDate ?? .distantPast
    }

    var timeSpan: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var hasBurstPhotos: Bool {
        assets.contains { $0.isBurst }
    }

    var hasLocationData: Bool {
        assets.contains { $0.locationDescription != nil }
    }

    init(assets: [PhotoAsset]) {
        self.assets = assets
        id = assets.map(\.id).joined(separator: "|")
    }
}
