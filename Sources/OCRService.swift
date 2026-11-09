import UIKit
import Vision

/// Vision 框架中文 OCR。全程在设备端运行，不产生任何网络请求。
enum OCRService {
    static func recognize(_ image: UIImage, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let text = recognizeSync(image)
            DispatchQueue.main.async { completion(text) }
        }
    }

    static func recognizeSync(_ image: UIImage) -> String {
        guard let ci = ImageProcessor.orientedCIImage(image),
              let cg = ImageProcessor.ciContext.createCGImage(ci, from: ci.extent.integral) else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false   // 证件号码不能被"智能纠错"改写

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        guard let observations = request.results else { return "" }

        let items: [(CGRect, String)] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return (obs.boundingBox, candidate.string)
        }
        let sorted = items.sorted { a, b in
            if abs(a.0.origin.y - b.0.origin.y) > 0.012 { return a.0.origin.y > b.0.origin.y }
            return a.0.origin.x < b.0.origin.x
        }
        return sorted.map { $0.1 }.joined(separator: "\n")
    }

    /// 合并多页 OCR 文本（用于跨页找字段）
    static func combinedText(_ texts: [String]) -> String {
        texts.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
