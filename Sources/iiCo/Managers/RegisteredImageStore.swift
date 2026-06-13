import Foundation
import UIKit

enum ImageDisplayEffectType: String, Codable, CaseIterable, Identifiable {
    case none
    case vibration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "なし"
        case .vibration:
            return "バイブ"
        }
    }
}

struct RegisteredImage: Identifiable, Codable, Equatable {
    let id: String
    let fileName: String
    var appearancePercentage: Int
    var effectType: ImageDisplayEffectType
    var audioFileName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case appearancePercentage
        case effectType
        case audioFileName
    }

    init(id: String, fileName: String, appearancePercentage: Int, effectType: ImageDisplayEffectType, audioFileName: String?) {
        self.id = id
        self.fileName = fileName
        self.appearancePercentage = appearancePercentage
        self.effectType = effectType
        self.audioFileName = audioFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        appearancePercentage = try container.decodeIfPresent(Int.self, forKey: .appearancePercentage) ?? 0
        effectType = try container.decodeIfPresent(ImageDisplayEffectType.self, forKey: .effectType) ?? .vibration
        audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
    }
}

final class RegisteredImageStore: ObservableObject {
    static let shared = RegisteredImageStore()

    static let maxImageCount = 100

    @Published private(set) var images: [RegisteredImage] = []

    private let metadataFileName = "registered-images.json"
    private let maxPixelSize: CGFloat = 512

    private var metadataURL: URL {
        documentsDirectory.appendingPathComponent(metadataFileName)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {
        load()
    }

    var canAddMoreImages: Bool {
        images.count < Self.maxImageCount
    }

    var remainingImageSlots: Int {
        max(0, Self.maxImageCount - images.count)
    }

    func addImage(from data: Data) -> Bool {
        guard canAddMoreImages else { return false }

        guard let original = UIImage(data: data),
              let normalized = original.normalized,
              let resized = normalized.resized(maxPixelSize: maxPixelSize),
              let jpeg = resized.jpegData(compressionQuality: 0.82) else {
            return false
        }

        let id = UUID().uuidString
        let fileName = "registered-\(id).jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            try jpeg.write(to: fileURL, options: .atomic)
            let remaining = remainingAssignablePercentage(excludingID: nil)
            let item = RegisteredImage(
                id: id,
                fileName: fileName,
                appearancePercentage: min(20, remaining),
                effectType: .vibration,
                audioFileName: nil
            )
            images.append(item)
            persistMetadata()
            return true
        } catch {
            return false
        }
    }

    func remove(at offsets: IndexSet) {
        let targets = offsets.map { images[$0] }
        for image in targets {
            let fileURL = documentsDirectory.appendingPathComponent(image.fileName)
            try? FileManager.default.removeItem(at: fileURL)

            if let audioFileName = image.audioFileName {
                let audioURL = documentsDirectory.appendingPathComponent(audioFileName)
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        images.remove(atOffsets: offsets)
        persistMetadata()
    }

    func remove(id: String) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        remove(at: IndexSet(integer: index))
    }

    func randomImageID() -> String? {
        images.randomElement()?.id
    }

    func weightedRandomImageID() -> String? {
        let weighted = images.filter { $0.appearancePercentage > 0 }
        let total = weighted.reduce(0) { $0 + $1.appearancePercentage }
        guard total > 0 else { return nil }

        var roll = Int.random(in: 1...total)
        for image in weighted {
            roll -= image.appearancePercentage
            if roll <= 0 { return image.id }
        }
        return weighted.last?.id
    }

    func totalAssignedPercentage() -> Int {
        images.reduce(0) { $0 + max(0, $1.appearancePercentage) }
    }

    func remainingAssignablePercentage(excludingID: String?) -> Int {
        let used = images.reduce(0) { partial, image in
            if image.id == excludingID {
                return partial
            }
            return partial + max(0, image.appearancePercentage)
        }
        return max(0, 100 - used)
    }

    func updateAppearancePercentage(id: String, percentage: Int) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        let value = min(max(percentage, 0), 100)
        images[index].appearancePercentage = value
        persistMetadata()
    }

    func updateEffectType(id: String, effectType: ImageDisplayEffectType) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        images[index].effectType = effectType
        persistMetadata()
    }

    func updateAudioFileName(id: String, audioFileName: String?) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        images[index].audioFileName = audioFileName
        persistMetadata()
    }

    func imageEntry(for id: String) -> RegisteredImage? {
        images.first(where: { $0.id == id })
    }

    func audioURL(for id: String) -> URL? {
        guard let image = images.first(where: { $0.id == id }),
              let audioFileName = image.audioFileName else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(audioFileName)
    }

    func hasAudio(for id: String) -> Bool {
        guard let url = audioURL(for: id) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func uiImage(for id: String) -> UIImage? {
        guard let image = images.first(where: { $0.id == id }) else { return nil }
        let fileURL = documentsDirectory.appendingPathComponent(image.fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL) else {
            images = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([RegisteredImage].self, from: data) else {
            images = []
            return
        }

        // メタデータとファイルの不整合を起動時に掃除
        images = decoded.compactMap { image in
            let fileURL = documentsDirectory.appendingPathComponent(image.fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

            var cleaned = image
            if let audioFileName = cleaned.audioFileName {
                let audioURL = documentsDirectory.appendingPathComponent(audioFileName)
                if !FileManager.default.fileExists(atPath: audioURL.path) {
                    cleaned.audioFileName = nil
                }
            }
            return cleaned
        }

        if images.count != decoded.count {
            persistMetadata()
        }
    }

    private func persistMetadata() {
        guard let data = try? JSONEncoder().encode(images) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}

private extension UIImage {
    var normalized: UIImage? {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func resized(maxPixelSize: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxPixelSize else { return self }

        let scale = maxPixelSize / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
