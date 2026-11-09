import UIKit

/// 图像滤镜（原始图始终保留，滤镜只在显示 / 导出时实时应用，可随时切换）
enum ImageFilter: String, Codable, CaseIterable {
    case original
    case enhance
    case grayscale
    case bw

    var title: String {
        switch self {
        case .original: return "原图"
        case .enhance: return "增强"
        case .grayscale: return "灰度"
        case .bw: return "黑白"
        }
    }

    var hint: String {
        switch self {
        case .original: return "不做处理"
        case .enhance: return "提亮阴影、增对比、锐化"
        case .grayscale: return "去色，适合彩色证件"
        case .bw: return "复印件效果，文字最清晰"
        }
    }
}

struct ScanPage: Codable, Identifiable, Equatable {
    var id: UUID
    var fileName: String
    var label: String
    var filter: ImageFilter
    var rotation: Int          // 顺时针旋转次数 × 90°
    var ocrText: String
    var createdAt: Date

    init(id: UUID = UUID(),
         fileName: String,
         label: String,
         filter: ImageFilter = .enhance,
         rotation: Int = 0,
         ocrText: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.label = label
        self.filter = filter
        self.rotation = rotation
        self.ocrText = ocrText
        self.createdAt = createdAt
    }
}

struct ScannedDocument: Codable, Identifiable, Equatable {
    var id: UUID
    var type: DocumentType
    var title: String
    var pages: [ScanPage]
    var fields: [String: String]
    var watermark: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         type: DocumentType,
         title: String? = nil,
         pages: [ScanPage] = [],
         fields: [String: String] = [:],
         watermark: String = "仅供办理业务使用 再次复印无效",
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title ?? type.defaultTitle
        self.pages = pages
        self.fields = fields
        self.watermark = watermark
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var summary: String {
        "\(type.title) · \(pages.count) 页"
    }
}

/// 扫描流程中尚未落盘的草稿页
struct DraftPage: Equatable {
    var id = UUID()
    var image: UIImage
    var label: String
    var filter: ImageFilter
    var rotation: Int
    var ocrText: String = ""

    init(image: UIImage, label: String, filter: ImageFilter = .enhance, rotation: Int = 0) {
        self.image = image
        self.label = label
        self.filter = filter
        self.rotation = rotation
    }

    /// 应用滤镜与旋转后的成图
    var rendered: UIImage {
        var img = ImageProcessor.apply(filter, to: image)
        if rotation > 0 {
            for _ in 0..<(rotation % 4) { img = ImageProcessor.rotateRight(img) }
        }
        return img
    }
}
