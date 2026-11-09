import UIKit

/// 扫描结果预览：逐页调滤镜 / 旋转 / 改名 / 增删 / OCR，确认后落盘。
final class ReviewViewController: UIViewController {
    private var type: DocumentType
    private var drafts: [DraftPage]
    private var current = 0
    private var appendingTo: UUID?
    private var coordinator: ScanCoordinator?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let typeButton = Theme.softButton("")
    private let previewCard = Theme.cardView(radius: 16)
    private let imageView = UIImageView()
    private let pageLabel = Theme.makeLabel(size: 13, weight: .medium, color: Theme.secondary)
    private let prevButton = Theme.softButton("上一页")
    private let nextButton = Theme.softButton("下一页")
    private let thumbStrip: UICollectionView
    private let segment = UISegmentedControl(items: ImageFilter.allCases.map { $0.title })
    private let hintLabel = Theme.makeLabel(size: 11.5, color: Theme.secondary, lines: 2)
    private let saveButton = Theme.primaryButton("保存扫描件", symbol: "square.and.arrow.down")

    init(type: DocumentType, images: [UIImage], appendingTo: UUID? = nil) {
        self.type = type
        self.drafts = images.enumerated().map { idx, image in
            DraftPage(image: image,
                      label: idx < type.pageNames.count ? type.pageNames[idx] : "第 \(idx + 1) 页",
                      filter: .enhance)
        }
        self.appendingTo = appendingTo
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2)
        self.thumbStrip = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = appendingTo == nil ? "预览扫描件" : "添加页面"
        view.backgroundColor = Theme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor(hex: 0xF7F9FC)
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewCard.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -10),
            previewCard.heightAnchor.constraint(equalToConstant: 300)
        ])

        thumbStrip.translatesAutoresizingMaskIntoConstraints = false
        thumbStrip.backgroundColor = .clear
        thumbStrip.showsHorizontalScrollIndicator = false
        thumbStrip.dataSource = self
        thumbStrip.delegate = self
        thumbStrip.register(ThumbCell.self, forCellWithReuseIdentifier: "Thumb")
        thumbStrip.heightAnchor.constraint(equalToConstant: 88).isActive = true

        segment.selectedSegmentIndex = 1
        segment.translatesAutoresizingMaskIntoConstraints = false
        segment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        pageLabel.textAlignment = .center
        hintLabel.textAlignment = .center
        typeButton.addTarget(self, action: #selector(changeType), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(prevPage), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let typeRow = horizontal([
            Theme.makeLabel("证件类型：", size: 13, color: Theme.secondary),
            typeButton,
            UIView()
        ], spacing: 8)
        let pageRow = horizontal([prevButton, pageLabel, nextButton], spacing: 10, equally: true)
        let row1 = horizontal([
            actionButton("旋转 90°", "rotate.right", #selector(rotatePage)),
            actionButton("重命名本页", "pencil", #selector(renamePage)),
            actionButton("删除本页", "trash", #selector(deletePage))
        ], spacing: 8, equally: true)
        let row2 = horizontal([
            actionButton("再加一页", "plus.viewfinder", #selector(addMore)),
            actionButton("识别文字", "text.viewfinder", #selector(runOCR)),
            actionButton("全部增强", "wand.and.stars", #selector(enhanceAll))
        ], spacing: 8, equally: true)

        let filterTitle = Theme.makeLabel("图像效果", size: 13, weight: .semibold)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        [typeRow, previewCard, pageRow, thumbStrip, filterTitle, segment, hintLabel, row1, row2, saveButton].forEach {
            stack.addArrangedSubview($0)
        }
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
            segment.heightAnchor.constraint(equalToConstant: 34),
            saveButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        refresh()
    }

    private func horizontal(_ views: [UIView], spacing: CGFloat, equally: Bool = false) -> UIStackView {
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = spacing
        s.alignment = equally ? .fill : .center
        s.distribution = equally ? .fillEqually : .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        s.heightAnchor.constraint(equalToConstant: equally ? 38 : 36).isActive = true
        return s
    }

    private func actionButton(_ title: String, _ symbol: String, _ selector: Selector) -> UIButton {
        let b = Theme.softButton(title, symbol: symbol)
        b.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        b.addTarget(self, action: selector, for: .touchUpInside)
        return b
    }

    // MARK: - 状态刷新

    private func refresh() {
        typeButton.setTitle(type.title + "  ▾", for: .normal)
        guard !drafts.isEmpty else {
            imageView.image = Theme.symbol("doc.badge.plus", size: 60)?.withTintColor(Theme.secondary, renderingMode: .alwaysOriginal)
            pageLabel.text = "暂无页面 · 点「再加一页」继续"
            hintLabel.text = "该证件拍摄建议：\(type.tips)"
            saveButton.isEnabled = false
            thumbStrip.reloadData()
            return
        }
        saveButton.isEnabled = true
        current = max(0, min(current, drafts.count - 1))
        let draft = drafts[current]
        imageView.image = draft.rendered
        pageLabel.text = "\(current + 1) / \(drafts.count) · \(draft.label)"
        segment.selectedSegmentIndex = ImageFilter.allCases.firstIndex(of: draft.filter) ?? 1
        hintLabel.text = "\(draft.filter.hint) · " + (draft.ocrText.isEmpty ? "尚未识别文字" : "已识别 \(draft.ocrText.count) 字符")
        saveButton.setTitle(appendingTo == nil ? "保存扫描件（\(drafts.count) 页）" : "添加这 \(drafts.count) 页", for: .normal)
        thumbStrip.reloadData()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.thumbStrip.selectItem(at: IndexPath(item: self.current, section: 0), animated: false,
                                       scrollPosition: .centeredHorizontally)
        }
    }

    // MARK: - 操作

    @objc private func filterChanged() {
        guard !drafts.isEmpty else { return }
        drafts[current].filter = ImageFilter.allCases[segment.selectedSegmentIndex]
        refresh()
    }

    @objc private func rotatePage() {
        guard !drafts.isEmpty else { return }
        drafts[current].rotation = (drafts[current].rotation + 1) % 4
        drafts[current].ocrText = ""
        refresh()
    }

    @objc private func renamePage() {
        guard !drafts.isEmpty else { return }
        ds_askText("重命名页面", placeholder: "如：人像面 / 主页", initial: drafts[current].label) { [weak self] value in
            guard let self = self, !value.isEmpty else { return }
            self.drafts[self.current].label = value
            self.refresh()
        }
    }

    @objc private func deletePage() {
        guard !drafts.isEmpty else { return }
        let label = drafts[current].label
        ds_confirm("删除「\(label)」？", "删除后无法恢复。", destructive: "删除") { [weak self] in
            guard let self = self else { return }
            self.drafts.remove(at: self.current)
            self.current = max(0, min(self.current, self.drafts.count - 1))
            self.refresh()
        }
    }

    @objc private func prevPage() {
        guard !drafts.isEmpty else { return }
        current = (current - 1 + drafts.count) % drafts.count
        refresh()
    }

    @objc private func nextPage() {
        guard !drafts.isEmpty else { return }
        current = (current + 1) % drafts.count
        refresh()
    }

    @objc private func enhanceAll() {
        drafts.indices.forEach { drafts[$0].filter = .enhance }
        ds_toast("已为全部页面应用「增强」效果")
        refresh()
    }

    @objc private func changeType() {
        let ac = UIAlertController(title: "选择证件类型", message: "切换后会按新类型的页面顺序重新命名，已拍图片不变。", preferredStyle: .actionSheet)
        for item in DocumentType.allCases {
            ac.addAction(UIAlertAction(title: item.title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.type = item
                for i in self.drafts.indices {
                    self.drafts[i].label = i < item.pageNames.count ? item.pageNames[i] : "第 \(i + 1) 页"
                }
                self.refresh()
            })
        }
        ac.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let pop = ac.popoverPresentationController {
            pop.sourceView = typeButton
            pop.sourceRect = typeButton.bounds
        }
        present(ac, animated: true)
    }

    @objc private func addMore() {
        let c = ScanCoordinator(presenter: self, type: type)
        c.onImages = { [weak self] images in
            guard let self = self else { return }
            for image in images {
                let idx = self.drafts.count
                self.drafts.append(DraftPage(image: image,
                                             label: idx < self.type.pageNames.count ? self.type.pageNames[idx] : "第 \(idx + 1) 页"))
            }
            self.current = max(0, self.drafts.count - images.count)
            self.coordinator = nil
            self.refresh()
        }
        c.onCancel = { [weak self] in self?.coordinator = nil }
        coordinator = c
        let ac = UIAlertController(title: "添加页面", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "文档相机扫描", style: .default) { _ in c.startCamera() })
        ac.addAction(UIAlertAction(title: "从相册导入", style: .default) { _ in c.startPhotoLibrary() })
        ac.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in self?.coordinator = nil })
        if let pop = ac.popoverPresentationController { pop.sourceView = view; pop.sourceRect = view.bounds }
        present(ac, animated: true)
    }

    @objc private func runOCR() {
        guard !drafts.isEmpty else { return }
        let loading = DSLoadingView.show(in: view, text: "正在识别文字…")
        let group = DispatchGroup()
        var results = Array(repeating: "", count: drafts.count)
        for (i, draft) in drafts.enumerated() {
            let image = draft.rendered
            group.enter()
            OCRService.recognize(image) { text in
                results[i] = text
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            for i in self.drafts.indices where i < results.count { self.drafts[i].ocrText = results[i] }
            loading.hide()
            self.refresh()
            self.ds_toast("识别完成，共 \(results.joined().count) 字符；保存时会自动提取字段")
        }
    }

    @objc private func saveTapped() {
        guard !drafts.isEmpty else { return }
        view.endEditing(true)
        let loading = DSLoadingView.show(in: view, text: "正在保存并整理字段…")
        let snapshot = drafts
        let targetID = appendingTo
        let docType = type

        DispatchQueue.global(qos: .userInitiated).async {
            var texts = snapshot.map { $0.ocrText }
            let rendered = snapshot.map { $0.rendered }
            for i in texts.indices where texts[i].isEmpty {
                texts[i] = OCRService.recognizeSync(rendered[i])
            }
            let combined = OCRService.combinedText(texts)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var newPages: [ScanPage] = []
                for (i, draft) in snapshot.enumerated() {
                    guard let fileName = Store.shared.saveImage(draft.image) else { continue }
                    newPages.append(ScanPage(fileName: fileName,
                                             label: draft.label,
                                             filter: draft.filter,
                                             rotation: draft.rotation,
                                             ocrText: texts[i]))
                }
                guard !newPages.isEmpty else {
                    loading.hide()
                    self.ds_alert("保存失败", "图片写入失败，请检查设备存储空间。")
                    return
                }

                var savedID: UUID
                if let targetID = targetID, var doc = Store.shared.document(id: targetID) {
                    doc.pages.append(contentsOf: newPages)
                    let allText = OCRService.combinedText(doc.pages.map { $0.ocrText })
                    let fresh = FieldExtractor.extract(from: allText, type: doc.type)
                    for (key, value) in fresh where doc.fields[key] == nil || doc.fields[key]?.isEmpty == true {
                        doc.fields[key] = value
                    }
                    Store.shared.upsert(doc)
                    savedID = doc.id
                    loading.hide()
                    if let target = self.navigationController?.viewControllers.compactMap({ $0 as? DetailViewController }).first {
                        self.navigationController?.popToViewController(target, animated: true)
                    } else {
                        self.navigationController?.popViewController(animated: true)
                    }
                } else {
                    var doc = ScannedDocument(type: docType, pages: newPages)
                    doc.fields = FieldExtractor.extract(from: combined, type: docType)
                    Store.shared.upsert(doc)
                    savedID = doc.id
                    loading.hide()
                    let home = self.navigationController?.viewControllers.first ?? HomeViewController()
                    let detail = DetailViewController(documentID: savedID)
                    self.navigationController?.setViewControllers([home, detail], animated: true)
                }
                _ = savedID
            }
        }
    }

    @objc private func cancel() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - 缩略图条

extension ReviewViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        drafts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Thumb", for: indexPath) as! ThumbCell
        cell.configure(drafts[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 62, height: 84)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        current = indexPath.item
        refresh()
    }
}

final class ThumbCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let label = Theme.makeLabel(size: 9, color: Theme.secondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 7
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        contentView.addSubview(imageView)
        contentView.addSubview(label)
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.clear.cgColor
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            imageView.heightAnchor.constraint(equalToConstant: 62),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 3),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ page: DraftPage) {
        imageView.image = page.rendered
        label.text = page.label
    }

    override var isSelected: Bool {
        didSet {
            contentView.layer.borderColor = isSelected ? Theme.primary.cgColor : UIColor.clear.cgColor
            label.textColor = isSelected ? Theme.primary : Theme.secondary
        }
    }
}
