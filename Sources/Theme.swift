import UIKit

// MARK: - 配色与排版

enum Theme {
    static let primary = UIColor(hex: 0x1A62D6)
    static let primarySoft = UIColor(hex: 0xE8F0FE)
    static let ink = UIColor(hex: 0x17212F)
    static let secondary = UIColor(hex: 0x6B7688)
    static let hairline = UIColor(hex: 0xE5E9F0)
    static let background = UIColor(hex: 0xF4F6FA)
    static let card = UIColor.white
    static let danger = UIColor(hex: 0xE0483C)
    static let success = UIColor(hex: 0x1E9E68)
    static let warning = UIColor(hex: 0xE8912A)

    static func makeLabel(_ text: String = "",
                          size: CGFloat = 15,
                          weight: UIFont.Weight = .regular,
                          color: UIColor = ink,
                          lines: Int = 1) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = lines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func cardView(radius: CGFloat = 16) -> UIView {
        let v = UIView()
        v.backgroundColor = card
        v.layer.cornerRadius = radius
        v.layer.cornerCurve = .continuous
        v.layer.shadowColor = UIColor(hex: 0x1A2B4A).cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowOffset = CGSize(width: 0, height: 3)
        v.layer.shadowRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    /// 使用传统 UIButton API（不依赖 iOS 15 的 UIButton.Configuration），兼容 iOS 14
    static func primaryButton(_ title: String, symbol: String? = nil) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = primary
        b.layer.cornerRadius = 10
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
        if let symbol = symbol {
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.tintColor = .white
            b.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    static func softButton(_ title: String, symbol: String? = nil) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        b.setTitleColor(primary, for: .normal)
        b.backgroundColor = primarySoft
        b.layer.cornerRadius = 9
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        if let symbol = symbol {
            b.setImage(UIImage(systemName: symbol, withConfiguration:
                UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
            b.tintColor = primary
            b.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    static func symbol(_ name: String, size: CGFloat = 22, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - 通用弹窗 / 提示

extension UIViewController {
    func ds_alert(_ title: String,
                  _ message: String? = nil,
                  actions: [UIAlertAction] = [UIAlertAction(title: "好", style: .default)],
                  style: UIAlertController.Style = .alert,
                  sourceView: UIView? = nil) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: style)
        actions.forEach { ac.addAction($0) }
        if let pop = ac.popoverPresentationController {
            pop.sourceView = sourceView ?? view
            pop.sourceRect = (sourceView ?? view).bounds
            pop.permittedArrowDirections = []
        }
        present(ac, animated: true)
    }

    func ds_confirm(_ title: String, _ message: String? = nil, destructive: String, action: @escaping () -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "取消", style: .cancel))
        ac.addAction(UIAlertAction(title: destructive, style: .destructive) { _ in action() })
        present(ac, animated: true)
    }

    func ds_askText(_ title: String,
                    message: String? = nil,
                    placeholder: String = "",
                    initial: String = "",
                    done: @escaping (String) -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addTextField {
            $0.placeholder = placeholder
            $0.text = initial
            $0.clearButtonMode = .whileEditing
        }
        ac.addAction(UIAlertAction(title: "取消", style: .cancel))
        ac.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            done(ac.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        })
        present(ac, animated: true)
    }

    func ds_toast(_ message: String) {
        let holder = UIView()
        holder.backgroundColor = UIColor(hex: 0x17212F).withAlphaComponent(0.92)
        holder.layer.cornerRadius = 12
        holder.alpha = 0
        holder.translatesAutoresizingMaskIntoConstraints = false
        let label = Theme.makeLabel(message, size: 14, weight: .medium, color: .white, lines: 2)
        label.textAlignment = .center
        holder.addSubview(label)
        view.addSubview(holder)
        NSLayoutConstraint.activate([
            holder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            holder.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            holder.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.86),
            label.topAnchor.constraint(equalTo: holder.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -18)
        ])
        UIView.animate(withDuration: 0.22, animations: { holder.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: { holder.alpha = 0 }) { _ in
                holder.removeFromSuperview()
            }
        }
    }
}

extension Date {
    var ds_display: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: self)
    }
    var ds_fileStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: self)
    }
}
