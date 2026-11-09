import UIKit
import CoreImage

/// 文档图像增强：全部基于 Core Image，纯本地 GPU/CPU 运算。
enum ImageProcessor {
    static let ciContext = CIContext()

    /// UIImage 方向 → EXIF 方向值
    private static func exifOrientation(_ o: UIImage.Orientation) -> Int32 {
        switch o {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }

    /// 得到"方向已摆正"的 CIImage（与屏幕所见一致）
    static func orientedCIImage(_ image: UIImage) -> CIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        return ci.oriented(forExifOrientation: exifOrientation(image.imageOrientation))
    }

    static func render(_ ci: CIImage) -> UIImage {
        guard let cg = ciContext.createCGImage(ci, from: ci.extent.integral) else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    /// 应用滤镜。原图始终 return 原 UIImage，不重新编码。
    static func apply(_ filter: ImageFilter, to image: UIImage) -> UIImage {
        guard filter != .original else { return image }
        guard let input = orientedCIImage(image) else { return image }
        var ci = input
        switch filter {
        case .original:
            break
        case .enhance:
            ci = ci.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.55,
                "inputShadowAmount": 0.72,
                "inputRadius": 6.0
            ])
            ci = ci.applyingFilter("CIColorControls", parameters: [
                "inputContrast": 1.14,
                "inputSaturation": 1.04,
                "inputBrightness": 0.012
            ])
            ci = ci.applyingFilter("CIUnsharpMask", parameters: [
                "inputRadius": 1.4,
                "inputIntensity": 0.55
            ])
        case .grayscale:
            ci = ci.applyingFilter("CIPhotoEffectMono")
            ci = ci.applyingFilter("CIColorControls", parameters: [
                "inputContrast": 1.18,
                "inputBrightness": 0.01
            ])
        case .bw:
            ci = ci.applyingFilter("CIPhotoEffectMono")
            ci = ci.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.3,
                "inputShadowAmount": 0.45
            ])
            ci = ci.applyingFilter("CIColorControls", parameters: [
                "inputContrast": 1.62,
                "inputBrightness": 0.055,
                "inputSaturation": 0
            ])
            ci = ci.applyingFilter("CIUnsharpMask", parameters: [
                "inputRadius": 1.1,
                "inputIntensity": 0.65
            ])
        }
        return render(ci.cropped(to: input.extent))
    }

    /// 旋转 90°（多按几次即可 180° / 270°）
    static func rotateRight(_ image: UIImage) -> UIImage {
        guard let ci = orientedCIImage(image) else { return image }
        return render(ci.oriented(forExifOrientation: 6))
    }
}
