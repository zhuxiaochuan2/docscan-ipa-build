import UIKit
import VisionKit
import PhotosUI
import Photos

/// 两种取图入口：VisionKit 文档相机（自动找边 + 透视校正）与系统相册多选。
final class ScanCoordinator: NSObject {
    private weak var presenter: UIViewController?
    let type: DocumentType
    var onImages: (([UIImage]) -> Void)?
    var onCancel: (() -> Void)?

    init(presenter: UIViewController, type: DocumentType) {
        self.presenter = presenter
        self.type = type
        super.init()
    }

    /// 文档相机：自动边缘检测、自动快门、自动梯形校正
    func startCamera() {
        guard VNDocumentCameraViewController.isSupported else {
            presenter?.ds_alert("不支持文档相机", "当前设备/系统无法使用 VisionKit 文档扫描，请改用「从相册导入」。")
            return
        }
        let vc = VNDocumentCameraViewController()
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen
        presenter?.present(vc, animated: true)
    }

    /// 相册导入（PHPicker，无需完整相册权限）
    func startPhotoLibrary() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    /// 直接调起系统相机（备用，不自动切边）
    func startSystemCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presenter?.ds_alert("相机不可用")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    fileprivate func deliver(_ images: [UIImage], from vc: UIViewController) {
        vc.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if images.isEmpty { self.onCancel?() } else { self.onImages?(images) }
        }
    }
}

// MARK: - VisionKit 文档相机

extension ScanCoordinator: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFinishWith scan: VNDocumentCameraScan) {
        var images: [UIImage] = []
        for i in 0..<scan.pageCount {
            images.append(scan.imageOfPage(at: i))
        }
        deliver(images, from: controller)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) { [weak self] in self?.onCancel?() }
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFailWithError error: Error) {
        controller.dismiss(animated: true) { [weak self] in
            self?.presenter?.ds_alert("扫描失败", error.localizedDescription)
            self?.onCancel?()
        }
    }
}

// MARK: - 相册多选

extension ScanCoordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard !results.isEmpty else {
            picker.dismiss(animated: true) { [weak self] in self?.onCancel?() }
            return
        }
        let group = DispatchGroup()
        var ordered: [UIImage?] = Array(repeating: nil, count: results.count)
        for (idx, result) in results.enumerated() {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage { ordered[idx] = ImageProcessor.render(ImageProcessor.orientedCIImage(image) ?? CIImage()) }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.deliver(ordered.compactMap { $0 }, from: picker)
        }
    }
}

// MARK: - 备用系统相机

extension ScanCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.originalImage] as? UIImage).map { [ImageProcessor.render(ImageProcessor.orientedCIImage($0) ?? CIImage())] } ?? []
        deliver(image, from: picker)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in self?.onCancel?() }
    }
}
