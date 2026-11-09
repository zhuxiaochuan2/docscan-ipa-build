import UIKit

// MARK: - 证件类型卡片

final class TypeCell: UICollectionViewCell {
    private let card = Theme.cardView(radius: 16)
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = Theme.makeLabel(size: 16, weight: .semibold)
    private let subtitleLabel = Theme.makeLabel(size: 11.5, color: Theme.secondary, lines: 2)
    private let pageBadge = Theme.makeLabel(size: 10, weight: .medium, color: Theme.primary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(card)
        iconBox.layer.cornerRadius = 11
        iconBox.layer.cornerCurve = .continuous
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(iconView)
        [iconBox, titleLabel, subtitleLabel, pageBadge].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconBox.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            iconBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconBox.widthAnchor.constraint(equalToConstant: 38),
            iconBox.heightAnchor.constraint(equalToConstant: 38),
            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 23),
            iconView.heightAnchor.constraint(equalToConstant: 23),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            pageBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            pageBadge.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ type: DocumentType) {
        iconBox.backgroundColor = type.tint.withAlphaComponent(0.12)
        iconView.image = Theme.symbol(type.symbol, size: 21, weight: .semibold)
        iconView.tintColor = type.tint
        titleLabel.text = type.title
        subtitleLabel.text = type.subtitle
        pageBadge.text = "建议 \(type.pageNames.count) 页 · 点击扫描"
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

// MARK: - 最近文档

final class DocCell: UICollectionViewCell {
    private let card = Theme.cardView(radius: 14)
    private let thumb = UIImageView()
    private let titleLabel = Theme.makeLabel(size: 15, weight: .semibold)
    private let infoLabel = Theme.makeLabel(size: 12, color: Theme.secondary)
    private let dateLabel = Theme.makeLabel(size: 11, color: Theme.secondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 8
        thumb.backgroundColor = Theme.background
        thumb.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        [thumb, titleLabel, infoLabel, dateLabel].forEach { card.addSubview($0) }
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            thumb.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            thumb.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 56),
            thumb.heightAnchor.constraint(equalToConstant: 56),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            titleLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            infoLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ doc: ScannedDocument) {
        titleLabel.text = doc.title
        infoLabel.text = doc.summary
        dateLabel.text = "更新于 " + doc.updatedAt.ds_display
        if let page = doc.pages.first {
            thumb.image = Store.shared.renderedImage(page)
        } else {
            thumb.image = Theme.symbol("doc", size: 24)
            thumb.tintColor = Theme.secondary
        }
    }
}

// MARK: - 空状态

final class HintCell: UICollectionViewCell {
    private let card = Theme.cardView(radius: 14)
    private let label = Theme.makeLabel(size: 13, color: Theme.secondary, lines: 2)

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        contentView.addSubview(card)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ text: String) { label.text = text }
}

// MARK: - 首页顶部横幅

final class HomeBannerView: UICollectionReusableView {
    var onCamera: (() -> Void)?
    var onLibrary: (() -> Void)?

    private let card = Theme.cardView(radius: 18)
    private let titleLabel = Theme.makeLabel("智能识别，拍完即成扫描件", size: 16, weight: .semibold)
    private let descLabel = Theme.makeLabel("自动找边 · 透视校正 · 图像增强 · 本地 OCR · A4 拼版 PDF", size: 12, color: Theme.secondary, lines: 2)
    private let cameraButton = Theme.primaryButton("开始扫描", symbol: "camera.viewfinder")
    private let libraryButton = Theme.softButton("相册导入", symbol: "photo")
    private let privacyLabel = Theme.makeLabel("所有图像与识别均在本机完成，不上传云端", size: 11, color: Theme.success, lines: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(card)
        [titleLabel, descLabel, cameraButton, libraryButton, privacyLabel].forEach { card.addSubview($0) }
        cameraButton.addTarget(self, action: #selector(tapCamera), for: .touchUpInside)
        libraryButton.addTarget(self, action: #selector(tapLibrary), for: .touchUpInside)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            cameraButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 14),
            cameraButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            libraryButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            libraryButton.leadingAnchor.constraint(equalTo: cameraButton.trailingAnchor, constant: 10),
            privacyLabel.topAnchor.constraint(equalTo: cameraButton.bottomAnchor, constant: 12),
            privacyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapCamera() { onCamera?() }
    @objc private func tapLibrary() { onLibrary?() }
}

// MARK: - 分区标题

final class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = Theme.makeLabel(size: 17, weight: .bold)
    private let detailLabel = Theme.makeLabel(size: 12, color: Theme.secondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        addSubview(detailLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            detailLabel.lastBaselineAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail
    }
}

// MARK: - 轻量加载遮罩

final class DSLoadingView: UIView {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = Theme.makeLabel(size: 13, weight: .medium, color: .white)

    static func show(in host: UIView, text: String) -> DSLoadingView {
        let v = DSLoadingView()
        v.backgroundColor = UIColor(hex: 0x17212F).withAlphaComponent(0.86)
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        v.label.text = text
        v.spinner.color = .white
        v.spinner.startAnimating()
        v.spinner.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(v.spinner)
        v.addSubview(v.label)
        host.addSubview(v)
        NSLayoutConstraint.activate([
            v.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            v.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            v.spinner.topAnchor.constraint(equalTo: v.topAnchor, constant: 18),
            v.spinner.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            v.label.topAnchor.constraint(equalTo: v.spinner.bottomAnchor, constant: 10),
            v.label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 22),
            v.label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -22),
            v.label.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -18)
        ])
        v.alpha = 0
        UIView.animate(withDuration: 0.18) { v.alpha = 1 }
        return v
    }

    func hide() {
        UIView.animate(withDuration: 0.18, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }
}
