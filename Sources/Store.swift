import UIKit

/// 全本地存储：元数据一个 JSON，原图逐张 JPEG。不联网、不上传、不写 iCloud。
final class Store {
    static let shared = Store()

    let rootURL: URL
    let imagesURL: URL
    let exportsURL: URL
    private let metaURL: URL
    private(set) var documents: [ScannedDocument] = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootURL = base.appendingPathComponent("DocScan", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("Images", isDirectory: true)
        exportsURL = rootURL.appendingPathComponent("Exports", isDirectory: true)
        metaURL = rootURL.appendingPathComponent("documents.json")
        [rootURL, imagesURL, exportsURL].forEach {
            try? FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }
        reload()
    }

    // MARK: - 元数据

    func reload() {
        guard let data = try? Data(contentsOf: metaURL),
              let list = try? decoder.decode([ScannedDocument].self, from: data) else {
            documents = []
            return
        }
        documents = list
    }

    func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        try? data.write(to: metaURL, options: .atomic)
    }

    var sortedDocuments: [ScannedDocument] {
        documents.sorted { $0.updatedAt > $1.updatedAt }
    }

    func document(id: UUID) -> ScannedDocument? {
        documents.first { $0.id == id }
    }

    func upsert(_ doc: ScannedDocument) {
        var value = doc
        value.updatedAt = Date()
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[idx] = value
        } else {
            documents.append(value)
        }
        persist()
    }

    func delete(_ id: UUID) {
        guard let doc = document(id: id) else { return }
        doc.pages.forEach { deleteImage($0.fileName) }
        documents.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 图片

    /// 保存原图（JPEG 质量 0.92，不做方向破坏），返回文件名
    @discardableResult
    func saveImage(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        do {
            try data.write(to: imagesURL.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func image(named fileName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: imagesURL.appendingPathComponent(fileName)) else { return nil }
        return UIImage(data: data)
    }

    func deleteImage(_ fileName: String) {
        try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(fileName))
    }

    /// 取出某页并应用其滤镜 / 旋转
    func renderedImage(_ page: ScanPage) -> UIImage? {
        guard var img = image(named: page.fileName) else { return nil }
        img = ImageProcessor.apply(page.filter, to: img)
        for _ in 0..<(page.rotation % 4) { img = ImageProcessor.rotateRight(img) }
        return img
    }

    func exportURL(_ fileName: String) -> URL {
        exportsURL.appendingPathComponent(fileName)
    }
}
