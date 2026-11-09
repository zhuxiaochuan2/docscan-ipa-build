import UIKit

/// 一条字段提取规则：先用正则在 OCR 全文中找，找不到再用关键词在行内取值。
struct FieldRule {
    let name: String
    let patterns: [String]
    let keywords: [String]

    init(_ name: String, patterns: [String] = [], keywords: [String] = []) {
        self.name = name
        self.patterns = patterns
        self.keywords = keywords
    }
}

/// 支持的 8 类证件。
enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case idCard
    case householdRegister
    case businessLicense
    case bankCard
    case passport
    case propertyCertificate
    case drivingLicense
    case vehicleLicense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idCard: return "身份证"
        case .householdRegister: return "户口本"
        case .businessLicense: return "营业执照"
        case .bankCard: return "银行卡"
        case .passport: return "护照"
        case .propertyCertificate: return "房产证"
        case .drivingLicense: return "驾驶证"
        case .vehicleLicense: return "行驶证"
        }
    }

    var subtitle: String {
        switch self {
        case .idCard: return "正反面 · 18 位号码校验"
        case .householdRegister: return "户主页 / 本人页"
        case .businessLicense: return "统一社会信用代码"
        case .bankCard: return "卡号 · 发卡行"
        case .passport: return "资料页 · MRZ 机读码"
        case .propertyCertificate: return "不动产权证 · 权利人页"
        case .drivingLicense: return "主页 / 副页"
        case .vehicleLicense: return "主页 / 副页 · 车牌 VIN"
        }
    }

    var symbol: String {
        switch self {
        case .idCard: return "person.crop.rectangle"
        case .householdRegister: return "book.closed"
        case .businessLicense: return "building.2"
        case .bankCard: return "creditcard"
        case .passport: return "book"
        case .propertyCertificate: return "house"
        case .drivingLicense: return "car.fill"
        case .vehicleLicense: return "doc.text"
        }
    }

    var tint: UIColor {
        switch self {
        case .idCard: return UIColor(hex: 0x1A62D6)
        case .householdRegister: return UIColor(hex: 0x7A54C8)
        case .businessLicense: return UIColor(hex: 0x0F8F78)
        case .bankCard: return UIColor(hex: 0xE07A24)
        case .passport: return UIColor(hex: 0x2F6C9E)
        case .propertyCertificate: return UIColor(hex: 0xC0455C)
        case .drivingLicense: return UIColor(hex: 0x356FA8)
        case .vehicleLicense: return UIColor(hex: 0x5C7A3C)
        }
    }

    /// 建议页数与页面名称（扫描时自动命名，可手动改）
    var pageNames: [String] {
        switch self {
        case .idCard: return ["人像面", "国徽面"]
        case .householdRegister: return ["户主页", "本人页", "其他成员页"]
        case .businessLicense: return ["正本", "副本"]
        case .bankCard: return ["卡面"]
        case .passport: return ["资料页", "备注页"]
        case .propertyCertificate: return ["封面/扉页", "权利人页", "附图页"]
        case .drivingLicense: return ["主页", "副页"]
        case .vehicleLicense: return ["主页", "副页"]
        }
    }

    /// 用于"自动判断证件类型"的目标宽高比（宽 / 高，横向拍摄时归一化后取 >1）
    var aspectRatio: CGFloat {
        switch self {
        case .idCard: return 85.6 / 54.0
        case .bankCard: return 85.6 / 54.0
        case .householdRegister: return 210.0 / 297.0
        case .businessLicense: return 297.0 / 420.0
        case .passport: return 125.0 / 88.0
        case .propertyCertificate: return 210.0 / 297.0
        case .drivingLicense: return 1.42
        case .vehicleLicense: return 1.42
        }
    }

    var tips: String {
        switch self {
        case .idCard: return "放在深色纯色背景上，四角完整入镜，避免反光与手指遮挡。"
        case .householdRegister: return "摊平拍摄，尽量让整页文字清晰；户主页与本人页建议分开扫。"
        case .businessLicense: return "正本较大，建议分段拍摄或保证光线均匀；二维码区域不要反光。"
        case .bankCard: return "凸字卡注意避免侧光阴影；可用「黑白」滤镜提升卡号对比度。"
        case .passport: return "资料页需完整包含底部两行机读码（MRZ），便于自动解析。"
        case .propertyCertificate: return "重点拍摄带证号与权利人信息的页面，附图表可另存一页。"
        case .drivingLicense: return "主页与副页分别扫描，副页的记录条也要拍清楚。"
        case .vehicleLicense: return "主页含号牌与 VIN，副页含检验记录，建议都扫。"
        }
    }

    var defaultTitle: String { "我的" + title }

    /// OCR 字段规则（顺序即详情页展示顺序）
    var fieldRules: [FieldRule] {
        switch self {
        case .idCard:
            return [
                FieldRule("姓名", patterns: [#"(?<![\u4e00-\u9fa5])姓\s*名[:：\s]*([\u4e00-\u9fa5·]{2,8})"#, #"姓\s*名\s+([\u4e00-\u9fa5·]{2,8})"#], keywords: ["姓名"]),
                FieldRule("性别", patterns: [#"(?:性别|性\s*别)[:：\s]*([男女])"#], keywords: ["性别"]),
                FieldRule("民族", patterns: [#"(?:民族|民\s*族)[:：\s]*([\u4e00-\u9fa5]{1,6})"#], keywords: ["民族"]),
                FieldRule("出生日期", patterns: [#"(?:19|20)\d{2}\s*[年./-]\s*\d{1,2}\s*[月./-]\s*\d{1,2}"#], keywords: ["出生"]),
                FieldRule("住址", patterns: [#"(?:住址|住\s*址)[:：\s]*([\u4e00-\u9fa5A-Za-z0-9（）()号楼室栋单元村路街号-]{4,60})"#], keywords: ["住址", "地址"]),
                FieldRule("公民身份号码", patterns: [#"(?<!\d)[1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx](?!\d)"#], keywords: ["公民身份号码", "身份号码", "身份证号码"]),
                FieldRule("签发机关", patterns: [#"(?:签发机关|签发单位)[:：\s]*([\u4e00-\u9fa5]{2,30})"#], keywords: ["签发机关"]),
                FieldRule("有效期限", patterns: [#"(?:20|19)\d{2}[.]\d{2}[.]\d{2}\s*[-—~至]\s*(?:(?:20|19)\d{2}[.]\d{2}[.]\d{2}|长期)"#], keywords: ["有效期限"])
            ]
        case .householdRegister:
            return [
                FieldRule("户别", patterns: [#"(?:户\s*别)[:：\s]*([\u4e00-\u9fa5]{2,12})"#], keywords: ["户别"]),
                FieldRule("户主姓名", patterns: [#"(?:户主姓名|户\s*主)[:：\s]*([\u4e00-\u9fa5·]{2,8})"#], keywords: ["户主姓名", "户主"]),
                FieldRule("户号", patterns: [#"(?<!\d)\d{9,18}(?!\d)"#], keywords: ["户号"]),
                FieldRule("姓名", patterns: [#"(?<![\u4e00-\u9fa5])姓\s*名[:：\s]*([\u4e00-\u9fa5·]{2,8})"#], keywords: ["姓名"]),
                FieldRule("与户主关系", patterns: [#"(?:与户主关系|与\s*户主\s*关系)[:：\s]*([\u4e00-\u9fa5]{1,10})"#], keywords: ["与户主关系", "关系"]),
                FieldRule("身份证号", patterns: [#"(?<!\d)[1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx](?!\d)"#], keywords: ["身份证号", "公民身份号码"]),
                FieldRule("住址", patterns: [], keywords: ["住址", "现住址", "地址"]),
                FieldRule("登记机关", patterns: [], keywords: ["登记机关", "承办人"])
            ]
        case .businessLicense:
            return [
                FieldRule("统一社会信用代码", patterns: [#"(?<![0-9A-Z])[0-9A-HJ-NPQRTUWXY]{2}\d{6}[0-9A-HJ-NPQRTUWXY]{10}(?![0-9A-Z])"#], keywords: ["统一社会信用代码"]),
                FieldRule("名称", patterns: [#"(?:名\s*称|企业名称)[:：\s]*([\u4e00-\u9fa5A-Za-z0-9（）()·]{2,40})"#], keywords: ["名称"]),
                FieldRule("类型", patterns: [#"(?:类\s*型|企业类型)[:：\s]*([\u4e00-\u9fa5（）()]{2,30})"#], keywords: ["类型"]),
                FieldRule("法定代表人", patterns: [#"(?:法定代表人|负责人|经营者)[:：\s]*([\u4e00-\u9fa5·]{2,12})"#], keywords: ["法定代表人", "负责人", "经营者"]),
                FieldRule("注册资本", patterns: [#"(?:注册资本|资金数额)[:：\s]*([\u4e00-\u9fa5A-Za-z0-9.]{1,30})"#], keywords: ["注册资本", "资金数额"]),
                FieldRule("成立日期", patterns: [#"(?:成立日期|注册日期)[:：\s]*((?:19|20)\d{2}[年./-]\d{1,2}[月./-]?\d{0,2}日?)"#], keywords: ["成立日期"]),
                FieldRule("住所", patterns: [], keywords: ["住所", "经营场所", "地址"]),
                FieldRule("经营范围", patterns: [], keywords: ["经营范围"]),
                FieldRule("登记机关", patterns: [], keywords: ["登记机关"]),
                FieldRule("营业期限", patterns: [], keywords: ["营业期限"])
            ]
        case .bankCard:
            return [
                FieldRule("卡号", patterns: [#"(?<!\d)(?:\d[ -]?){15,18}\d(?!\d)"#], keywords: ["卡号"]),
                FieldRule("发卡行", patterns: [], keywords: ["银行", "BANK"]),
                FieldRule("持卡人", patterns: [#"(?:持卡人|MR\.|MS\.)[:：\s]*([A-Z\u4e00-\u9fa5 ]{2,30})"#], keywords: ["持卡人"]),
                FieldRule("有效期", patterns: [#"(?<!\d)(0[1-9]|1[0-2])\s*/\s*(\d{2}|\d{4})(?!\d)"#], keywords: ["有效期", "VALID"]),
                FieldRule("卡组织", patterns: [#"(?i)(visa|mastercard|unionpay|银联|jcb|amex)"#], keywords: [])
            ]
        case .passport:
            return [
                FieldRule("护照号码", patterns: [#"(?<!\d)(?:[EGDSP]\d{8}|[A-Z]{2}\d{7}|[A-Z]\d{8})(?!\d)"#], keywords: ["护照号码", "PASSPORT NO"]),
                FieldRule("姓名", patterns: [#"(?:姓\s*名|Name)[:：\s]*([\u4e00-\u9fa5A-Z ]{2,40})"#], keywords: ["姓名", "Name"]),
                FieldRule("性别", patterns: [#"(?:性别|Sex)[:：\s]*([男女MF])"#], keywords: ["性别", "Sex"]),
                FieldRule("出生日期", patterns: [#"(?:19|20)\d{2}[年./-]\d{1,2}[月./-]\d{1,2}"#], keywords: ["出生日期", "Date of birth"]),
                FieldRule("出生地点", patterns: [], keywords: ["出生地点", "Place of birth"]),
                FieldRule("签发日期", patterns: [], keywords: ["签发日期", "Date of issue"]),
                FieldRule("有效期至", patterns: [], keywords: ["有效期至", "Date of expiry"]),
                FieldRule("签发机关", patterns: [], keywords: ["签发机关", "Authority"]),
                FieldRule("国籍", patterns: [], keywords: ["国籍", "Nationality"]),
                FieldRule("机读码 MRZ", patterns: [#"[A-Z0-9<]{40,46}"#], keywords: [])
            ]
        case .propertyCertificate:
            return [
                FieldRule("不动产权证号", patterns: [#"(?:[（(]?\s*(?:19|20)\d{2}\s*[)）]?\s*)?[\u4e00-\u9fa5]{0,8}不动产权第\s*\d+\s*号"#, #"(?<!\d)\d{4,8}\s*[-—]\s*\d{4,12}(?!\d)"#], keywords: ["不动产权第", "权证号", "证书号"]),
                FieldRule("权利人", patterns: [#"(?:权利人|房屋所有权人|土地使用权人)[:：\s]*([\u4e00-\u9fa5·A-Za-z0-9（）()]{2,40})"#], keywords: ["权利人", "所有权人"]),
                FieldRule("共有情况", patterns: [#"(?:共有情况)[:：\s]*([\u4e00-\u9fa5]{1,20})"#], keywords: ["共有情况"]),
                FieldRule("坐落", patterns: [], keywords: ["坐落", "房屋坐落", "所在地"]),
                FieldRule("用途", patterns: [#"(?:用\s*途)[:：\s]*([\u4e00-\u9fa5]{1,20})"#], keywords: ["用途"]),
                FieldRule("面积", patterns: [#"\d+(?:\.\d+)?\s*(?:平方米|㎡|m2)"#], keywords: ["面积"]),
                FieldRule("使用期限", patterns: [], keywords: ["使用期限"]),
                FieldRule("登记机构", patterns: [], keywords: ["登记机构", "填发单位"]),
                FieldRule("身份证号", patterns: [#"(?<!\d)[1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx](?!\d)"#], keywords: ["身份证号"])
            ]
        case .drivingLicense:
            return [
                FieldRule("姓名", patterns: [#"(?<![\u4e00-\u9fa5])姓\s*名[:：\s]*([\u4e00-\u9fa5·]{2,8})"#], keywords: ["姓名"]),
                FieldRule("性别", patterns: [#"(?:性别)[:：\s]*([男女])"#], keywords: ["性别"]),
                FieldRule("国籍", patterns: [#"(?:国籍)[:：\s]*([\u4e00-\u9fa5]{2,20})"#], keywords: ["国籍"]),
                FieldRule("证号", patterns: [#"(?<!\d)[1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx](?!\d)"#], keywords: ["证号", "身份证号"]),
                FieldRule("住址", patterns: [], keywords: ["住址", "地址"]),
                FieldRule("准驾车型", patterns: [#"(?:准驾车型)[:：\s]*([A-Z0-9,，、]{1,20})"#], keywords: ["准驾车型"]),
                FieldRule("初次领证日期", patterns: [], keywords: ["初次领证", "初次领证日期"]),
                FieldRule("有效期限", patterns: [#"(?:(?:19|20)\d{2}[年./-]\d{1,2}[月./-]\d{1,2}日?\s*(?:至|-|—)\s*(?:19|20)\d{2}[年./-]\d{1,2}[月./-]\d{1,2}日?)|(?:有效期\s*\d+\s*年)"#], keywords: ["有效期限"]),
                FieldRule("档案编号", patterns: [#"(?<!\d)\d{10,14}(?!\d)"#], keywords: ["档案编号"])
            ]
        case .vehicleLicense:
            return [
                FieldRule("号牌号码", patterns: [#"[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-Z][A-Z0-9]{5,7}"#], keywords: ["号牌号码", "车牌"]),
                FieldRule("车辆类型", patterns: [#"(?:车辆类型)[:：\s]*([\u4e00-\u9fa5]{2,20})"#], keywords: ["车辆类型"]),
                FieldRule("所有人", patterns: [#"(?:所\s*有\s*人|车主)[:：\s]*([\u4e00-\u9fa5·A-Za-z0-9（）()]{2,40})"#], keywords: ["所有人"]),
                FieldRule("住址", patterns: [], keywords: ["住址", "地址"]),
                FieldRule("品牌型号", patterns: [#"(?:品牌型号)[:：\s]*([A-Za-z0-9\u4e00-\u9fa5\-()（）]{2,40})"#], keywords: ["品牌型号"]),
                FieldRule("车辆识别代号 VIN", patterns: [#"(?<!\d)[A-HJ-NPR-Z0-9]{17}(?!\d)"#], keywords: ["车辆识别代号", "VIN", "车架号"]),
                FieldRule("发动机号码", patterns: [#"(?:发动机号码|发动机号)[:：\s]*([A-Za-z0-9\-]{4,25})"#], keywords: ["发动机号码", "发动机号"]),
                FieldRule("注册日期", patterns: [], keywords: ["注册日期"]),
                FieldRule("发证日期", patterns: [], keywords: ["发证日期"]),
                FieldRule("档案编号", patterns: [#"(?<!\d)\d{10,14}(?!\d)"#], keywords: ["档案编号"])
            ]
        }
    }

    /// 依据 OCR 关键词 + 图像宽高比，给出证件类型建议（用于"智能识别"入口）
    static func guess(text: String, ratio: CGFloat?) -> DocumentType? {
        let t = text.uppercased()
        if text.contains("公民身份号码") && (text.contains("签发机关") || text.contains("住址")) { return .idCard }
        if t.contains("统一社会信用代码") || t.contains("营业执照") { return .businessLicense }
        if t.contains("准驾车型") || t.contains("中华人民共和国机动车驾驶证") { return .drivingLicense }
        if t.contains("号牌号码") && t.contains("车辆识别代号") { return .vehicleLicense }
        if t.contains("不动产权") || t.contains("房屋所有权证") { return .propertyCertificate }
        if t.contains("户主") || t.contains("户号") || t.contains("常住人口登记卡") { return .householdRegister }
        if t.contains("PASSPORT") || t.contains("护照") || t.contains("P<CHN") { return .passport }
        if t.contains("UNIONPAY") || t.contains("银联") || t.contains("VALID THRU") { return .bankCard }
        guard let r = ratio, r > 1.35, r < 1.8 else { return nil }
        return .idCard
    }
}
