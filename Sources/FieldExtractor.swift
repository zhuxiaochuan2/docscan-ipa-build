import Foundation

/// 用「正则 + 关键词行内取值」把 OCR 文本整理成结构化字段。
/// 识别结果只是辅助，界面上所有字段都允许手动修改。
enum FieldExtractor {

    static func extract(from text: String, type: DocumentType) -> [String: String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let allKeywords = Array(Set(type.fieldRules.flatMap { $0.keywords })).sorted { $0.count > $1.count }
        var result: [String: String] = [:]

        for rule in type.fieldRules {
            var value: String?
            for pattern in rule.patterns {
                if let hit = firstMatch(pattern, in: text) { value = hit; break }
            }
            if value == nil {
                for keyword in rule.keywords {
                    for line in lines where line.contains(keyword) {
                        let candidate = valueAfter(keyword, in: line, cutKeywords: allKeywords)
                        if !clean(candidate).isEmpty { value = candidate; break }
                    }
                    if value != nil { break }
                }
            }
            if let v = value, !clean(v).isEmpty { result[rule.name] = clean(v) }
        }

        // 护照：机读码更可靠，用它补齐缺失字段
        if type == .passport {
            for (key, value) in parseMRZ(text) where result[key] == nil || result[key]?.isEmpty == true {
                result[key] = value
            }
        }

        // 银行卡：去空格、Luhn 校验提示
        if type == .bankCard, let card = result["卡号"] {
            let digits = card.filter { $0.isNumber }
            if digits.count >= 15 { result["卡号"] = digits }
        }
        return result
    }

    // MARK: - 底层工具

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let full = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: full) else { return nil }
        var r = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
        if r.location == NSNotFound { r = match.range(at: 0) }
        guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
        return String(text[swiftRange])
    }

    /// 从 "姓名 张三 性别 男" 这类同一行里，取出关键词后面、下一个关键词之前的片段
    private static func valueAfter(_ keyword: String, in line: String, cutKeywords: [String]) -> String {
        guard let r = line.range(of: keyword, options: [.caseInsensitive]) else { return "" }
        var rest = String(line[r.upperBound...])
        for kw in cutKeywords where kw != keyword {
            if let hit = rest.range(of: kw, options: [.caseInsensitive]) {
                rest = String(rest[..<hit.lowerBound])
            }
        }
        return rest
    }

    private static func clean(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: ":： \t.。|丨,，"))
        return String(trimmed.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 校验

    /// 18 位居民身份证校验码（GB 11643）
    static func isValidChineseID(_ raw: String) -> Bool {
        let id = raw.uppercased().filter { !$0.isWhitespace }
        guard id.count == 18 else { return false }
        let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
        let checkChars = Array("10X98765432")
        var sum = 0
        for (i, ch) in id.enumerated() where i < 17 {
            guard let digit = ch.wholeNumberValue else { return false }
            sum += digit * weights[i]
        }
        return id.last == checkChars[sum % 11]
    }

    /// Luhn 校验（银行卡号）
    static func isValidCardNumber(_ raw: String) -> Bool {
        let digits = raw.filter { $0.isNumber }
        guard (15...19).contains(digits.count) else { return false }
        var sum = 0
        let reversed = Array(digits.reversed())
        for (i, ch) in reversed.enumerated() {
            guard var d = ch.wholeNumberValue else { return false }
            if i % 2 == 1 {
                d *= 2
                if d > 9 { d -= 9 }
            }
            sum += d
        }
        return sum % 10 == 0
    }

    static func validationNote(for doc: ScannedDocument) -> String? {
        switch doc.type {
        case .idCard, .drivingLicense:
            let key = doc.type == .idCard ? "公民身份号码" : "证号"
            guard let id = doc.fields[key], !id.isEmpty else { return nil }
            return isValidChineseID(id) ? "证件号码校验通过" : "证件号码校验未通过，请核对识别结果"
        case .bankCard:
            guard let card = doc.fields["卡号"], !card.isEmpty else { return nil }
            return isValidCardNumber(card) ? "卡号 Luhn 校验通过" : "卡号校验未通过，请核对识别结果"
        default:
            return nil
        }
    }

    // MARK: - 护照机读码 TD3（两行 × 44 字符）

    static func parseMRZ(_ text: String) -> [String: String] {
        var candidates: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
            let s = rawLine.uppercased().filter { allowed.contains($0) }
            if (40...46).contains(s.count) { candidates.append(s) }
        }
        guard candidates.count >= 2 else { return [:] }
        let l1 = padded(String(candidates[candidates.count - 2].prefix(44)), 44)
        let l2 = padded(String(candidates[candidates.count - 1].prefix(44)), 44)
        guard l2.allSatisfy({ $0 != " " }) else { return [:] }

        var out: [String: String] = [:]
        let passportNo = sub(l2, 0, 9).replacingOccurrences(of: "<", with: "")
        if !passportNo.isEmpty { out["护照号码"] = passportNo }

        let country = sub(l1, 2, 3)
        if !country.isEmpty { out["国籍"] = country }

        let namePart = String(l1.dropFirst(5))
        let pieces = namePart.components(separatedBy: "<<")
        let surname = (pieces.first ?? "").replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
        let given = (pieces.count > 1 ? pieces[1] : "").replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
        let fullName = [surname, given].filter { !$0.isEmpty }.joined(separator: " ")
        if !fullName.isEmpty { out["姓名"] = fullName }

        let gender = sub(l2, 20, 1)
        if gender == "M" { out["性别"] = "男" } else if gender == "F" { out["性别"] = "女" }

        if let birth = mrzDate(sub(l2, 13, 6), expiryStyle: false) { out["出生日期"] = birth }
        if let expiry = mrzDate(sub(l2, 21, 6), expiryStyle: true) { out["有效期至"] = expiry }
        return out
    }

    private static func padded(_ s: String, _ n: Int) -> String {
        s.count >= n ? s : s + String(repeating: "<", count: n - s.count)
    }

    private static func sub(_ s: String, _ loc: Int, _ len: Int) -> String {
        let start = s.index(s.startIndex, offsetBy: min(loc, s.count))
        let end = s.index(start, offsetBy: min(len, s.distance(from: start, to: s.endIndex)))
        return String(s[start..<end])
    }

    private static func mrzDate(_ raw: String, expiryStyle: Bool) -> String? {
        guard raw.count == 6, raw.allSatisfy({ $0.isNumber }) else { return nil }
        let yy = Int(raw.prefix(2)) ?? 0
        let mm = String(raw.dropFirst(2).prefix(2))
        let dd = String(raw.suffix(2))
        guard (1...12).contains(Int(mm) ?? 0), (1...31).contains(Int(dd) ?? 0) else { return nil }
        let century: Int
        if expiryStyle {
            century = yy > 75 ? 1900 : 2000
        } else {
            century = yy > 25 ? 1900 : 2000
        }
        return "\(century + yy)年\(Int(mm) ?? 0)月\(Int(dd) ?? 0)日"
    }
}
