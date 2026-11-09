import UIKit

/// 证件详情：页面预览、字段编辑、水印、导出与分享。
final class DetailViewController: UIViewController {
    private let documentID: UUID
    private var doc: ScannedDocument?
    private var coordinator: ScanCoordinator?
    private var fieldKeys: [String] = []
    private var watermarkField: UITextField?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(documentID: UUID) {
        self.documentID = documentID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: Theme.symbol("pencil", size: 18), style: .plain,
            target: self, action: #selector(renameDocument))

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Store.shared.reload()
        doc = Store.shared.document(id: documentID)
        rebuild()
    }

    // MARK: - 构建界面

    private func rebuild() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        guard let doc = doc else {
            title = "已删除"
            let label = Theme.makeLabel("这份扫描件已不存在", size: 14, color: Theme.secondary, lines: 0)
            label.textAlignment = .center
            stack.addArrangedSubview(label)
            return
        }
        title = doc.title

        stack.addArrangedSubview(sectionTitle("扫描页面 · \(doc.pages.count) 页"))
        stack.addArrangedSubview(makeGallery(doc))

        let quick = UIStackView(arrangedSubviews: [
            softAction("继续加页", "plus.viewfinder", #selector(addPages)),
            softAction("重新识别字段", "text.viewfinder", #selector(rerunOCR)),
            softAction("查看 OCR 原文", "doc.plaintext", #selector(showRawText))
        ])
        quick.axis = .horizontal
        quick.distribution = .fillEqually
        quick.spacing = 8
        quick.translatesAutoresizingMaskIntoConstraints = false
        quick.heightAnchor.constraint(equalToConstant: 38).isActive = true
        stack.addArrangedSubview(quick)

        if let note = FieldExtractor.validationNote(for: doc) {
            let good = note.contains("通过") && !note.contains("未通过")
            let label = Theme.makeLabel((good ? "✓ " : "⚠ ") + note, size: 12,
                                        weight: .medium, color: good ? Theme.success : Theme.warning, lines: 2)
            stack.addArrangedSubview(label)
        }

        // 水印
        stack.addArrangedSubview(sectionTitle("防伪水印"))
        let waterCard = Theme.cardView(radius: 14)
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 14)
        field.placeholder = "留空则不加水印"
        field.text = doc.watermark
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.translatesAutoresizingMaskIntoConstraints = false
        field.addTarget(self, action: #selector(watermarkEnded), for: [.editingDidEnd, .editingDidEndOnExit])
        field.delegate = self
        watermarkField = field
        let waterHint = Theme.makeLabel("导出 PDF 时会以斜向浅红字平铺在整页，建议写明用途，例如「仅供办理 XX 业务使用」。",
                                        size: 11.5, color: Theme.secondary, lines: 3)
        waterCard.addSubview(field)
        waterCard.addSubview(waterHint)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: waterCard.topAnchor, constant: 14),
            field.leadingAnchor.constraint(equalTo: waterCard.leadingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: waterCard.trailingAnchor, constant: -14),
            field.heightAnchor.constraint(equalToConstant: 38),
            waterHint.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            waterHint.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            waterHint.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            waterHint.bottomAnchor.constraint(equalTo: waterCard.bottomAnchor, constant: -14)
        ])
        stack.addArrangedSubview(waterCard)

        // 字段
        stack.addArrangedSubview(sectionTitle("识别信息 · 点击可修改"))
        let fieldsCard = Theme.cardView(radius: 14)
        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false
        let ruleNames = doc.type.fieldRules.map { $0.name }
        let extras = doc.fields.keys.filter { !ruleNames.contains($0) }.sorted()
        fieldKeys = ruleNames + extras
        for (index, key) in fieldKeys.enumerated() {
            let row = makeFieldRow(key: key, value: doc.fields[key], tag: index)
            fieldsStack.addArrangedSubview(row)
            if index < fieldKeys.count - 1 {
                let line = UIView()
                line.backgroundColor = Theme.hairline
                line.translatesAutoresizingMaskIntoConstraints = false
                line.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
                fieldsStack.addArrangedSubview(line)
            }
        }
        fieldsCard.addSubview(fieldsStack)
        NSLayoutConstraint.activate([
            fieldsStack.topAnchor.constraint(equalTo: fieldsCard.topAnchor, constant: 4),
            fieldsStack.leadingAnchor.constraint(equalTo: fieldsCard.leadingAnchor, constant: 14),
            fieldsStack.trailingAnchor.constraint(equalTo: fieldsCard.trailingAnchor, constant: -14),
            fieldsStack.bottomAnchor.constraint(equalTo: fieldsCard.bottomAnchor, constant: -4)
        ])
        stack.addArrangedSubview(fieldsCard)
        let fieldsHint = Theme.makeLabel("OCR 结果仅供辅助核对，请对照原件确认后再使用。所有字段都可手动填写或修正。",
                                         size: 11.5, color: Theme.secondary, lines: 2)
        stack.addArrangedSubview(fieldsHint)

        // 导出
        stack.addArrangedSubview(sectionTitle("导出与分享"))
        let exportCard = Theme.cardView(radius: 14)
        let e1 = UIStackView(arrangedSubviews: [
            softAction("PDF · 每页 1 张", "doc.richtext", #selector(exportSingle)),
            softAction("PDF · 正反面拼版", "square.on.square", #selector(exportPaired))
        ])
        let e2 = UIStackView(arrangedSubviews: [
            softAction("分享 PDF", "square.and.arrow.up", #selector(sharePDF)),
            softAction("图片存相册", "photo.badge.plus", #selector(exportImages))
        ])
        [e1, e2].forEach {
            $0.axis = .horizontal
            $0.distribution = .fillEqually
            $0.spacing = 8
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
        let exportStack = UIStackView(arrangedSubviews: [e1, e2])
        exportStack.axis = .vertical
        exportStack.spacing = 8
        exportStack.translatesAutoresizingMaskIntoConstraints = false
        let exportHint = Theme.makeLabel("PDF 按 A4 排版可直接打印；生成的文件也会保存在 App 的「 Documents/DocScan/Exports 」目录，可通过「文件」App 的文件共享取出。",
                                         size: 11.5, color: Theme.secondary, lines: 3)
        exportCard.addSubview(exportStack)
        exportCard.addSubview(exportHint)
        NSLayoutConstraint.activate([
            exportStack.topAnchor.constraint(equalTo: exportCard.topAnchor, constant: 14),
            exportStack.leadingAnchor.constraint(equalTo: exportCard.leadingAnchor, constant: 14),
            exportStack.trailingAnchor.constraint(equalTo: exportCard.trailingAnchor, constant: -14),
            exportHint.topAnchor.constraint(equalTo: exportStack.bottomAnchor, constant: 10),
            exportHint.leadingAnchor.constraint(equalTo: exportCard.leadingAnchor, constant: 14),
            exportHint.trailingAnchor.constraint(equalTo: exportCard.trailingAnchor, constant: -14),
            exportHint.bottomAnchor.constraint(equalTo: exportCard.bottomAnchor, constant: -14)
        ])
        stack.addArrangedSubview(exportCard)

        let tips = Theme.makeLabel("拍摄建议：\(doc.type.tips)", size: 11.5, color: Theme.secondary, lines: 3)
        stack.addArrangedSubview(tips)

        let del = UIButton(type: .system)
        del.setTitle("删除这份扫描件", for: .normal)
        del.setTitleColor(Theme.danger, for: .normal)
        del.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        del.translatesAutoresizingMaskIntoConstraints = false
        del.addTarget(self, action: #selector(deleteDocument), for: .touchUpInside)
        del.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stack.addArrangedSubview(del)
        stack.addArrangedSubview(Theme.makeLabel("创建于 \(doc.createdAt.ds_display) · 全部数据仅存于本机",
                                                size: 11, color: Theme.secondary, lines: 1))
    }

    private func sectionTitle(_ text: String) -> UILabel {
        Theme.makeLabel(text, size: 15, weight: .bold)
    }

    private func softAction(_ title: String, _ symbol: String, _ selector: Selector) -> UIButton {
        let b = Theme.softButton(title, symbol: symbol)
        b.addTarget(self, action: selector, for: .touchUpInside)
        return b
    }

    private func makeFieldRow(key: String, value: String?, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(editField(_:)), for: .touchUpInside)
        let name = Theme.makeLabel(key, size: 13, color: Theme.secondary)
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        let valueLabel = Theme.makeLabel((value?.isEmpty ?? true) ? "未识别 · 点击填写" : value!,
                                         size: 14, weight: .medium,
                                         color: (value?.isEmpty ?? true) ? Theme.secondary : Theme.ink, lines: 2)
        let arrow = UIImageView(image: Theme.symbol("chevron.right", size: 13, weight: .semibold))
        arrow.tintColor = Theme.secondary
        arrow.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(name)
        button.addSubview(valueLabel)
        button.addSubview(arrow)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
            name.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            name.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            name.widthAnchor.constraint(equalToConstant: 122),
            valueLabel.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 6),
            valueLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -8),
            arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 10)
        ])
        return button
    }

    private func makeGallery(_ doc: ScannedDocument) -> UIView {
        let card = Theme.cardView(radius: 14)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.sectionInset = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.tag = 77
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PageCell.self, forCellWithReuseIdentifier: "PageCell")
        cv.dataSource = self
        cv.delegate = self
        cv.heightAnchor.constraint(equalToConstant: 220).isActive = true
        let hint = Theme.makeLabel("左右滑动查看全部 \(doc.pages.count) 页 · 点按可放大", size: 11, color: Theme.secondary)
        card.addSubview(cv)
        card.addSubview(hint)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            cv.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            cv.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            hint.topAnchor.constraint(equalTo: cv.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            hint.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)
        ])
        return card
    }

    // MARK: - 编辑

    @objc private func renameDocument() {
        guard let doc = doc else { return }
        ds_askText("重命名", placeholder: "给这份扫描件起个名字", initial: doc.title) { [weak self] value in
            guard let self = self, !value.isEmpty, var d = self.doc else { return }
            d.title = value
            Store.shared.upsert(d)
            self.doc = d
            self.rebuild()
        }
    }

    @objc private func editField(_ sender: UIButton) {
        guard sender.tag < fieldKeys.count, var d = doc else { return }
        let key = fieldKeys[sender.tag]
        ds_askText("编辑「\(key)」", placeholder: "请输入 \(key)", initial: d.fields[key] ?? "") { [weak self] value in
            guard let self = self else { return }
            d.fields[key] = value
            Store.shared.upsert(d)
            self.doc = d
            self.rebuild()
        }
    }

    @objc private func watermarkEnded() {
        guard var d = doc else { return }
        d.watermark = watermarkField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Store.shared.upsert(d)
        self.doc = d
    }

    @objc private func addPages() {
        guard let doc = doc else { return }
        let c = ScanCoordinator(presenter: self, type: doc.type)
        c.onImages = { [weak self] images in
            guard let self = self else { return }
            let review = ReviewViewController(type: doc.type, images: images, appendingTo: doc.id)
            self.navigationController?.pushViewController(review, animated: true)
            self.coordinator = nil
        }
        c.onCancel = { [weak self] in self?.coordinator = nil }
        coordinator = c
        c.startCamera()
    }

    @objc private func rerunOCR() {
        guard let doc = doc, !doc.pages.isEmpty else { return }
        let loading = DSLoadingView.show(in: view, text: "正在重新识别…")
        let images = doc.pages.compactMap { Store.shared.renderedImage($0) }
        let group = DispatchGroup()
        var texts = Array(repeating: "", count: images.count)
        for (i, image) in images.enumerated() {
            group.enter()
            OCRService.recognize(image) { text in texts[i] = text; group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self, var d = self.doc else { return }
            for i in d.pages.indices where i < texts.count { d.pages[i].ocrText = texts[i] }
            let fresh = FieldExtractor.extract(from: OCRService.combinedText(texts), type: d.type)
            for (k, v) in fresh where d.fields[k] == nil || d.fields[k]?.isEmpty == true { d.fields[k] = v }
            Store.shared.upsert(d)
            self.doc = d
            loading.hide()
            self.rebuild()
            self.ds_toast("识别完成，已补充空白字段（不会覆盖你的手动修改）")
        }
    }

    @objc private func showRawText() {
        guard let doc = doc else { return }
        let text = doc.pages.enumerated().map { "—— 第 \($0.offset + 1)页：\($0.element.label) ——\n\($0.element.ocrText)" }
            .joined(separator: "\n\n")
        let vc = PlainTextViewController(title: "OCR 原文", content: text.isEmpty ? "尚未识别文字，可点「重新识别字段」。" : text)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func deleteDocument() {
        guard let doc = doc else { return }
        ds_confirm("删除「\(doc.title)」？", "共 \(doc.pages.count) 页图片与识别结果会一并删除，无法恢复。", destructive: "确认删除") { [weak self] in
            Store.shared.delete(doc.id)
            self?.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - 导出

    private func makePDF(_ layout: PDFLayout) -> URL? {
        guard let doc = doc else { return nil }
        let options = PDFOptions(layout: layout, watermark: doc.watermark, addBorder: true, addFooter: true)
        return PDFBuilder.build(document: doc, options: options)
    }

    @objc private func exportSingle() {
        guard let url = makePDF(.onePerPage) else { ds_toast("生成失败，请先确认已有扫描页"); return }
        ds_alert("PDF 已生成", "已保存到 App 文档目录：\n\(url.lastPathComponent)\n\n可在「文件」App 的本应用文件共享中取出，也可以现在直接分享或打印。",
                 actions: [
                    UIAlertAction(title: "稍后", style: .cancel),
                    UIAlertAction(title: "立即分享", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        ShareSheet.present(items: [url], from: self)
                    }
                 ])
    }

    @objc private func exportPaired() {
        guard let url = makePDF(.twoPerPage) else { ds_toast("生成失败，请先确认已有扫描页"); return }
        ShareSheet.present(items: [url], from: self)
        ds_toast("已生成 A4 正反面拼版 PDF（含水印）")
    }

    @objc private func sharePDF() {
        guard let url = makePDF(.onePerPage) else { ds_toast("生成失败，请先确认已有扫描页"); return }
        ShareSheet.present(items: [url], from: self)
    }

    @objc private func exportImages() {
        guard let doc = doc else { return }
        let images = doc.pages.compactMap { Store.shared.renderedImage($0) }
        guard !images.isEmpty else { ds_toast("没有可导出的图片"); return }
        images.forEach { UIImageWriteToSavedPhotosAlbum($0, nil, nil, nil) }
        ds_toast("已请求保存 \(images.count) 张图片到系统相册")
    }
}

// MARK: - UITextField

extension DetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - 页面横向预览

extension DetailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        doc?.pages.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as! PageCell
        if let page = doc?.pages[indexPath.item] {
            cell.configure(image: Store.shared.renderedImage(page), label: page.label)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 220)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let doc = doc else { return }
        let images = doc.pages.compactMap { Store.shared.renderedImage($0) }
        let viewer = PageViewerController(images: images, startIndex: indexPath.item)
        viewer.modalPresentationStyle = .fullScreen
        present(viewer, animated: true)
    }
}

final class PageCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let label = Theme.makeLabel(size: 10, weight: .medium, color: Theme.secondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor(hex: 0xF7F9FC)
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        contentView.addSubview(imageView)
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            imageView.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(image: UIImage?, label text: String) {
        imageView.image = image
        label.text = text
    }
}

// MARK: - 全屏放大查看

final class PageViewerController: UIViewController, UIScrollViewDelegate {
    private let images: [UIImage]
    private let startIndex: Int
    private let outer = UIScrollView()
    private let pageLabel = Theme.makeLabel(size: 13, weight: .medium, color: .white)
    private var didSetup = false

    init(images: [UIImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        outer.isPagingEnabled = true
        outer.showsHorizontalScrollIndicator = false
        outer.delegate = self
        outer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outer)

        let close = UIButton(type: .system)
        close.setImage(Theme.symbol("xmark.circle.fill", size: 30), for: .normal)
        close.tintColor = .white
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(close)
        view.addSubview(pageLabel)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: view.topAnchor),
            outer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didSetup, !images.isEmpty else { return }
        // 第一次布局时按最终尺寸放置分页内容
        let w = outer.bounds.width
        let h = outer.bounds.height
        guard w > 0, h > 0 else { return }
        didSetup = true
        do {
            for (i, image) in images.enumerated() {
                let zoom = ZoomScrollView(frame: CGRect(x: w * CGFloat(i), y: 0, width: w, height: h))
                zoom.imageView.image = image
                zoom.minimumZoomScale = 1
                zoom.maximumZoomScale = 4
                zoom.delegate = self
                zoom.showsVerticalScrollIndicator = false
                zoom.showsHorizontalScrollIndicator = false
                outer.addSubview(zoom)
            }
            outer.contentSize = CGSize(width: w * CGFloat(images.count), height: h)
            outer.contentOffset = CGPoint(x: w * CGFloat(startIndex), y: 0)
            updateLabel()
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        (scrollView as? ZoomScrollView)?.imageView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === outer { updateLabel() }
    }

    private func updateLabel() {
        guard outer.bounds.width > 0 else { return }
        let index = Int(round(outer.contentOffset.x / outer.bounds.width)) + 1
        pageLabel.text = "\(min(max(index, 1), images.count)) / \(images.count)  ·  双指放大查看细节"
    }

    @objc private func closeTapped() { dismiss(animated: true) }
}

final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        addSubview(imageView)
        contentSize = bounds.size
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if imageView.frame.size != bounds.size, zoomScale == 1 {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }
}

// MARK: - 纯文本查看

final class PlainTextViewController: UIViewController {
    private let content: String

    init(title: String, content: String) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = .systemFont(ofSize: 14)
        tv.textColor = Theme.ink
        tv.isEditable = false
        tv.backgroundColor = .white
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        tv.text = content
        view.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tv.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }
}
