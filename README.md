# 证件扫描 · DocScan

一个给 **TrollStore（巨魔）** 侧载用的 iOS 原生证件扫描 App，功能对标「扫描全能王」的证件扫描场景：
自动找边拍照、透视校正、图像增强、OCR 字段提取、A4 拼版 PDF、防伪水印。

> 独立实现，UI 与交互为同类参考实现，**非 CamScanner / 扫描全能王 官方产品**，与其无任何关联。
> 全部能力基于系统框架（VisionKit / Vision / CoreImage / PDFKit 渲染 / PhotosUI），**无第三方 SDK、无网络请求、无账号、无上传**。

---

## 1. 支持哪些证件

| 证件 | 建议页 | 自动提取的字段 |
| --- | --- | --- |
| 身份证 | 人像面 / 国徽面 | 姓名、性别、民族、出生日期、住址、公民身份号码、签发机关、有效期限（含 18 位校验码验证） |
| 户口本 | 户主页 / 本人页 / 其他成员页 | 户别、户主姓名、户号、姓名、与户主关系、身份证号、住址、登记机关 |
| 营业执照 | 正本 / 副本 | 统一社会信用代码、名称、类型、法定代表人、注册资本、成立日期、住所、经营范围、登记机关、营业期限 |
| 银行卡 | 卡面 | 卡号、发卡行、持卡人、有效期、卡组织（含 Luhn 校验） |
| 护照 | 资料页 / 备注页 | 护照号码、姓名、性别、出生日期、出生地点、签发日期、有效期至、签发机关、国籍、**机读码 MRZ（TD3）解析** |
| 房产证 / 不动产权证 | 扉页 / 权利人页 / 附图页 | 证号、权利人、共有情况、坐落、用途、面积、使用期限、登记机构、身份证号 |
| 驾驶证 | 主页 / 副页 | 姓名、性别、国籍、证号、住址、准驾车型、初次领证日期、有效期限、档案编号 |
| 行驶证 | 主页 / 副页 | 号牌号码、车辆类型、所有人、住址、品牌型号、VIN、发动机号码、注册/发证日期、档案编号 |

**所有字段都能手动修改**，识别结果只是辅助；详情页会显示身份证号 / 卡号的校验是否通过。

## 2. 功能清单

- **拍摄**：`VNDocumentCameraViewController` 文档相机 —— 自动边缘检测、自动梯形/透视校正、多页连拍；也支持相册多选导入、系统相机兜底
- **智能识别**：不预先选类型直接拍，先 OCR 再结合宽高比自动判断证件种类，保存前仍可改
- **图像增强**：原图 / 增强（提亮阴影+对比+锐化）/ 灰度 / 黑白复印件效果，逐页独立设置；旋转 90°、重命名页面、增删页面、调整顺序
- **文字识别**：Vision 中文 OCR（`zh-Hans` + `en-US`，关闭语言纠错避免改错证件号）；按证件类型用正则 + 关键词行内取值结构化字段
- **导出**：A4 PDF（每页 1 张 / 每页 2 张正反面拼版）、细边框、图片说明、页脚、**斜向平铺红色防伪水印**、系统分享（含"存储到文件"/打印）、逐张图片存相册
- **全屏放大**：双指缩放查看扫描细节
- **本地存储**：`Documents/DocScan/` 下一个 `documents.json` + 逐张原图 JPEG；已开启 `UIFileSharingEnabled`，可用「文件」App 或 Finder 取出 PDF
- **隐私**：无网络权限声明、无统计、无云同步；证件图片只留在本机

---

## 3. 编译与安装（重点）

本项目是**未签名 ipa** 方案：Xcode 编译时关闭代码签名，TrollStore 安装时会自行完成永久签名。

### 环境要求

- 编译：**macOS + Xcode 15/16**（或 GitHub Actions 的 macOS 镜像）
- 运行：**iOS 14.0 及以上、arm64 的 iPhone/iPad**，已装好 TrollStore
- 想在 Windows 上直接产出 ipa 是不行的（Swift/iOS SDK 只在 macOS），请用下面的 **方案 C**：它会把编译搬到云端的 macOS 机器上，本机只要 Windows + Python 3 + 一个 GitHub 账号

### 方案 A：Mac 命令行一键出包

```bash
git clone <你的仓库> && cd DocScan
chmod +x build.sh
./build.sh
# 产出：build/DocScan-unsigned.ipa
```

脚本会：生成 Xcode 工程 → `xcodebuild` Release/iphoneos 关闭签名 → 打成 `Payload/DocScan.app` → zip 成 ipa。

### 方案 B：Mac 上用 Xcode 调试

```bash
python3 tools/gen_xcodeproj.py     # 生成 DocScan.xcodeproj
open DocScan.xcodeproj
```

选择 `DocScan` scheme，目标选真机，直接 Run 即可（工程已关闭签名）；或者 Product → Archive 后手动打包。
**新增/删除 Swift 文件后重新跑一次 `gen_xcodeproj.py`** 即可同步工程引用，不需要 XcodeGen。

### 方案 C：Windows 一键云端编译（不会命令行也能用，推荐）

**你只需要做一件事：生成一个 GitHub 令牌并粘贴一次。** 其余（建仓库、传源码、触发编译、等待、下载 ipa）全部自动完成。

1. 打开 <https://github.com/settings/tokens/new?scopes=repo,workflow&description=DocScan-Build>（没账号先去 <https://github.com/signup> 免费注册）
2. 拉到页面底部点 **Generate token**，复制 `ghp_` 开头那串字符
3. **双击项目根目录的 `build-ipa.bat`**，在弹出的窗口里粘贴 token 并回车
4. 等 5~10 分钟，窗口提示「编译完成」后，ipa 就在工作区根目录：`DocScan-unsigned.ipa`

脚本 `tools/build_remote.py` 做的事情：调用 GitHub 接口创建公开仓库并逐个上传源码 → 触发 `build-ipa.yml` → 轮询任务状态 → 下载编译产物。它**只走 `api.github.com`**，不需要 Git、不需要 GitHub CLI、不需要访问 github.com 网页，适合国内网络。

- 编译日志会保存为 `xcodebuild.log`；如果编译失败，把这个文件里最后的报错发出来即可定位修复
- 如果自动下载 artifact 失败（网络原因），窗口会打印任务页面链接，在浏览器里点 Artifacts 手动下载即可
- token 会存到 `tools/token.txt` 方便下次复用，该文件已被 `.gitignore` 排除且**不会上传到仓库**；用完建议删除该文件并在 GitHub 设置里撤销令牌

### 方案 D：手动走 GitHub Actions 网页

1. 在 GitHub 新建仓库，把本目录**全部文件**推上去（包含 `.github/workflows/build-ipa.yml`）
2. 打开仓库 → **Actions** → 左侧 `Build unsigned IPA` → **Run workflow**
3. 等约 5~10 分钟，任务完成后在页面底部 **Artifacts** 下载 `DocScan-unsigned-ipa`
4. 解压得到 `DocScan-unsigned.ipa`

> workflow 用的是 `macos-15` 镜像（自带 Xcode），执行 `gen_xcodeproj.py` + `xcodebuild ... CODE_SIGNING_ALLOWED=NO` + zip。只保留手动触发，避免重复编译。

### 安装到 iPhone

1. 把 `DocScan-unsigned.ipa` 传到手机（AirDrop / 微信文件传输 / 数据线 / Safari 下载均可），保存到「文件」App
2. 在「文件」里点该 ipa → 分享 → **用 TrollStore 打开**（或直接打开 TrollStore → 右上角导入 → 选中 ipa）
3. 点 **Install**，完成后桌面出现「证件扫描」
4. 首次进入授权相机 / 相册（相册导入用的是 PHPicker，不需要给完整相册权限）

### 常见问题

| 现象 | 处理 |
| --- | --- |
| TrollStore 提示不支持 / 安装失败 | 确认 ipa 根目录就是 `Payload/DocScan.app`，没有多套一层文件夹；重新用 `zip -qry xxx.ipa Payload` 打包 |
| 安装后闪退 | 确认系统 ≥ iOS 14.0；若仍闪退，用 Xcode 真机运行看崩溃日志 |
| 想改 App 名 / Bundle ID | 改 `Sources/Info.plist` 的 `CFBundleDisplayName`，以及 `tools/gen_xcodeproj.py` 里的 `BUNDLE_ID`，然后重新生成工程 |
| 想支持 iOS 13 | 不建议：PHPicker 与文档相机部分 API 需要 14+；iOS 14 已是巨魔主流下限 |
| OCR 识别不准 | 换「黑白」滤镜、保证光线均匀、避免反光；护照请完整拍入底部两行 MRZ；所有字段都能手动改 |
| PDF 里的水印想换颜色/密度 | 改 `Sources/PDFBuilder.swift` 的 `drawWatermark`，调整字号、透明度与 `stepX/stepY` |

---

## 4. 使用流程

1. 首页顶部「**开始扫描**」直接智能识别，或从 8 个证件卡片进入指定类型
2. 文档相机自动找边，连拍所有页面 → 完成
3. 预览页逐页切滤镜 / 旋转 / 改名 / 删除 / 加页 / 点「识别文字」
4. 保存后进入详情页：修改标题、补全字段、填写水印文字
5. 选「PDF · 正反面拼版」→ 直接分享 / 打印 / 存到「文件」

---

## 5. 目录结构

```
DocScan/
├── README.md
├── build-ipa.bat                      # ★ Windows 双击：云端编译并取回 ipa
├── build.sh                          # Mac 一键出未签名 ipa
├── .github/workflows/build-ipa.yml    # 云端 macOS 编译流程
├── tools/build_remote.py              # ★ Windows 云端编译助手（纯 API，无需 git/gh）
├── tools/gen_xcodeproj.py             # 生成 pbxproj / scheme / App 图标
├── DocScan.xcodeproj/                 # 由脚本生成，可随时重建
└── Sources/
    ├── Info.plist                     # 权限、文件共享、Scene 配置
    ├── Assets.xcassets/AppIcon.appiconset/
    ├── AppDelegate.swift / SceneDelegate.swift
    ├── Theme.swift                    # 配色、控件工厂、弹窗/Toast
    ├── DocumentType.swift             # 8 类证件规格与字段规则
    ├── Models.swift                   # ScanPage / ScannedDocument / DraftPage
    ├── Store.swift                    # JSON + 图片本地持久化
    ├── ImageProcessor.swift           # 4 种滤镜、方向归一化、旋转
    ├── ScanCamera.swift               # VisionKit 文档相机 / PHPicker / 系统相机
    ├── OCRService.swift               # Vision 中文 OCR
    ├── FieldExtractor.swift           # 正则字段提取 + 身份证/银行卡校验 + MRZ 解析
    ├── PDFBuilder.swift               # A4 排版、斜向水印、分享
    ├── Cells.swift                    # 首页卡片 / 横幅 / 加载遮罩
    ├── HomeViewController.swift       # 首页 + 智能识别入口
    ├── ReviewViewController.swift     # 扫描结果预览编辑
    └── DetailViewController.swift     # 详情、字段编辑、导出、全屏查看
```

---

## 6. 使用提醒

- 证件属于敏感个人信息，本工具**只在本机处理**，但请自行注意手机锁屏密码、别把导出的 PDF 随手传到不可信的群聊或网盘。
- 对外提供复印件时**务必保留水印**并写明用途，例如「仅供办理 XX 业务使用 再次复印无效」。
- 本项目仅供合法合规的资料整理使用，请勿用于伪造、变造证件或任何违法用途。
- 首次编译建议在真机上跑一遍完整流程（相机 → 保存 → PDF），OCR 效果受拍摄质量影响较大。
