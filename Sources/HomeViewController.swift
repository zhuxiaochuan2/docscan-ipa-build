import UIKit

final class HomeViewController: UIViewController {
    private let collectionView: UICollectionView
    private var docs: [ScannedDocument] = []
    private var coordinator: ScanCoordinator?

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 4, left: 16, bottom: 10, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "证件扫描"
        view.backgroundColor = Theme.background
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: Theme.symbol("info.circle", size: 20),
            style: .plain, target: self, action: #selector(showAbout))

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TypeCell.self, forCellWithReuseIdentifier: "TypeCell")
        collectionView.register(DocCell.self, forCellWithReuseIdentifier: "DocCell")
        collectionView.register(HintCell.self, forCellWithReuseIdentifier: "HintCell")
        collectionView.register(HomeBannerView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "Banner")
        collectionView.register(SectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "Header")
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Store.shared.reload()
        docs = Store.shared.sortedDocuments
        collectionView.reloadData()
    }

    @objc private func showAbout() {
        ds_alert("关于「证件扫描」", """
        独立实现的证件扫描工具，参考同类产品的交互思路，非 CamScanner / 扫描全能王 官方产品，与其无任何关联。

        · 支持 8 类证件：身份证、户口本、营业执照、银行卡、护照、房产证、驾驶证、行驶证
        · VisionKit 自动找边与透视校正，4 种图像增强滤镜
        · Vision 中文 OCR + 正则字段提取 + 身份证/银行卡校验 + 护照 MRZ 解析
        · A4 单页 / 正反面拼版 PDF，可加斜向防伪水印
        · 100% 本机处理：无网络请求、无账号、无第三方 SDK、无数据上传

        版本 1.0 · 通过 TrollStore 侧载安装
        """)
    }

    // MARK: - 扫描入口

    private func makeCoordinator(type: DocumentType?) -> ScanCoordinator {
        let c = ScanCoordinator(presenter: self, type: type ?? .idCard)
        c.onImages = { [weak self] images in
            self?.handle(images: images, suggestedType: type)
        }
        c.onCancel = { [weak self] in self?.coordinator = nil }
        coordinator = c
        return c
    }

    func startCamera(type: DocumentType? = nil) {
        makeCoordinator(type: type).startCamera()
    }

    func startLibrary(type: DocumentType? = nil) {
        makeCoordinator(type: type).startPhotoLibrary()
    }

    /// 若未指定类型，先 OCR 第一页自动判断证件种类
    private func handle(images: [UIImage], suggestedType: DocumentType?) {
        coordinator = nil
        guard !images.isEmpty else { return }
        guard let type = suggestedType else {
            let loading = DSLoadingView.show(in: view, text: "正在识别证件类型…")
            OCRService.recognize(images[0]) { [weak self] text in
                loading.hide()
                guard let self = self else { return }
                let ratio = images[0].size.width / max(images[0].size.height, 1)
                let normalized = max(ratio, 1 / max(ratio, 0.001))
                let guessed = DocumentType.guess(text: text, ratio: normalized) ?? .idCard
                self.ds_toast("已识别为「\(guessed.title)」，可在保存前修改")
                self.pushReview(images: images, type: guessed)
            }
            return
        }
        pushReview(images: images, type: type)
    }

    private func pushReview(images: [UIImage], type: DocumentType) {
        let review = ReviewViewController(type: type, images: images)
        navigationController?.pushViewController(review, animated: true)
    }
}

// MARK: - UICollectionView

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 3 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 1: return DocumentType.allCases.count
        case 2: return max(docs.count, 1)
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TypeCell", for: indexPath) as! TypeCell
            cell.configure(DocumentType.allCases[indexPath.item])
            return cell
        }
        if docs.isEmpty {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HintCell", for: indexPath) as! HintCell
            cell.configure("还没有扫描记录\n点上方任意证件类型，或从相册导入已有照片")
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DocCell", for: indexPath) as! DocCell
        cell.configure(docs[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            let banner = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                         withReuseIdentifier: "Banner",
                                                                         for: indexPath) as! HomeBannerView
            banner.onCamera = { [weak self] in self?.startCamera() }
            banner.onLibrary = { [weak self] in self?.startLibrary() }
            return banner
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                     withReuseIdentifier: "Header",
                                                                     for: indexPath) as! SectionHeaderView
        header.configure(title: indexPath.section == 1 ? "选择证件类型" : "最近扫描",
                         detail: indexPath.section == 1 ? "共 8 类" : "\(docs.count) 份")
        return header
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 1 {
            let w = (collectionView.bounds.width - 32 - 12) / 2
            return CGSize(width: floor(w), height: 104)
        }
        return CGSize(width: collectionView.bounds.width - 32, height: docs.isEmpty ? 82 : 80)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: section == 0 ? 172 : 44)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        section == 0 ? .zero : UIEdgeInsets(top: 4, left: 16, bottom: 12, right: 16)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath.section == 1 {
            startCamera(type: DocumentType.allCases[indexPath.item])
        } else if indexPath.section == 2, !docs.isEmpty {
            let detail = DetailViewController(documentID: docs[indexPath.item].id)
            navigationController?.pushViewController(detail, animated: true)
        }
    }
}
