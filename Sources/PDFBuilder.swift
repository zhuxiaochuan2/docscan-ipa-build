import UIKit

enum PDFLayout: CaseIterable {
    case onePerPage
    case twoPerPage

    var title: String {
        switch self {
        case .onePerPage: return "每页 1 张（A4 单页）"
        case .twoPerPage: return "每页 2 张（正反面拼版）"
        }
    }
}

struct PDFOptions {
    var layout: PDFLayout = .onePerPage
    var watermark: String = ""
    var addBorder: Bool = true
    var addFooter: Bool = true
}

/// 生成可直接打印的 A4 PDF：证件等比居中、细边框、斜向防伪水印、页脚说明。
enum PDFBuilder {
    static let a4 = CGSize(width: 595.28, height: 841.89)

    static func build(document: ScannedDocument, options: PDFOptions) -> URL? {
        let images = document.pages.compactMap { Store.shared.renderedImage($0) }
        guard !images.isEmpty else { return nil }

        let perPage = options.layout == .onePerPage ? 1 : 2
        var groups: [[UIImage]] = []
        var index = 0
        while index < images.count {
            groups.append(Array(images[index..<min(index + perPage, images.count)]))
            index += perPage
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = ["Title": document.title, "Author": "证件扫描", "Creator": "DocScan"] as [String: Any]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: a4), format: format)
        let fileName = "\(safeFileName(document.title))_\(Date().ds_fileStamp).pdf"
        let url = Store.shared.exportURL(fileName)

        do {
            try renderer.writePDF(to: url) { context in
                for (pageIndex, group) in groups.enumerated() {
                    context.beginPage()
                    let ctx = context.cgContext
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: a4))

                    let frame = CGRect(x: 44, y: 48, width: a4.width - 88, height: a4.height - 132)
                    for (i, image) in group.enumerated() {
                        var slot = frame
                        if group.count > 1 {
                            let half = (frame.height - 24) / 2
                            slot = CGRect(x: frame.minX,
                                          y: frame.minY + CGFloat(i) * (half + 24),
                                          width: frame.width,
                                          height: half)
                        }
                        draw(image, fitting: slot, border: options.addBorder, caption: caption(for: document, page: pageIndex * perPage + i))
                    }

                    if options.addFooter {
                        let footer = "由「证件扫描」本地生成 · \(document.title) · \(Date().ds_display) · 第 \(pageIndex + 1)/\(groups.count) 页"
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 9),
                            .foregroundColor: UIColor(hex: 0x98A2B3)
                        ]
                        let size = (footer as NSString).size(withAttributes: attrs)
                        (footer as NSString).draw(at: CGPoint(x: (a4.width - size.width) / 2, y: a4.height - 44),
                                                  withAttributes: attrs)
                    }
                    drawWatermark(options.watermark, in: CGRect(origin: .zero, size: a4))
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func caption(for doc: ScannedDocument, page: Int) -> String? {
        guard page < doc.pages.count else { return nil }
        return "\(doc.pages[page].label) · \(doc.type.title)"
    }

    private static func draw(_ image: UIImage, fitting rect: CGRect, border: Bool, caption: String?) {
        let captionHeight: CGFloat = 22
        let imageRect = CGRect(x: rect.minX, y: rect.minY,
                               width: rect.width, height: rect.height - captionHeight)
        let scale = min(imageRect.width / max(image.size.width, 1), imageRect.height / max(image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: imageRect.midX - size.width / 2, y: imageRect.midY - size.height / 2)
        let finalRect = CGRect(origin: origin, size: size)

        image.draw(in: finalRect)
        if border {
            UIColor(hex: 0xCBD3E0).setStroke()
            let path = UIBezierPath(rect: finalRect.insetBy(dx: -0.5, dy: -0.5))
            path.lineWidth = 0.8
            path.stroke()
        }
        if let caption = caption {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor(hex: 0x6B7688)
            ]
            let s = (caption as NSString).size(withAttributes: attrs)
            (caption as NSString).draw(at: CGPoint(x: rect.midX - s.width / 2, y: rect.maxY - captionHeight + 2),
                                       withAttributes: attrs)
        }
    }

    /// 斜向平铺水印：类似复印件"仅供…使用"防伪字样
    private static func drawWatermark(_ text: String, in rect: CGRect) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
            .foregroundColor: UIColor(hex: 0xD03028).withAlphaComponent(0.15)
        ]
        let str = NSString(string: content)
        let textSize = str.size(withAttributes: attrs)
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: -CGFloat.pi / 6)
        let stepX = textSize.width + 90
        let stepY: CGFloat = 165
        let radius = max(rect.width, rect.height) * 0.95
        var y: CGFloat = -radius
        var row = 0
        while y < radius {
            var x: CGFloat = -radius + (row % 2 == 0 ? 0 : stepX / 2)
            while x < radius {
                str.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
                x += stepX
            }
            y += stepY
            row += 1
        }
        ctx.restoreGState()
    }

    private static func safeFileName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")
        let cleaned = raw.components(separatedBy: invalid).joined(separator: "_")
        return cleaned.isEmpty ? "扫描件" : String(cleaned.prefix(40))
    }
}

enum ShareSheet {
    static func present(items: [Any], from vc: UIViewController, sourceView: UIView? = nil) {
        guard !items.isEmpty else { return }
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = ac.popoverPresentationController {
            pop.sourceView = sourceView ?? vc.view
            pop.sourceRect = sourceView?.bounds ?? CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        vc.present(ac, animated: true)
    }
}
