#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 DocScan.xcodeproj（无需 XcodeGen / Tuist / CocoaPods）。

用法（在仓库根目录执行）：
    python3 tools/gen_xcodeproj.py

它会自动扫描 Sources/*.swift，生成 project.pbxproj、shared scheme，
并生成一张 1024x1024 的 App 图标（纯 Python 标准库，不依赖 Pillow）。
新增/删除 Swift 文件后重新运行本脚本即可。
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"
PROJ = ROOT / "DocScan.xcodeproj"
SCHEMES = PROJ / "xcshareddata" / "xcschemes"
ICONSET = SOURCES / "Assets.xcassets" / "AppIcon.appiconset"

PRODUCT_NAME = "DocScan"
BUNDLE_ID = "com.docscan.local.certscanner"
DEPLOYMENT_TARGET = "14.0"

_counter = [0]
_ids: dict[str, str] = {}


def oid(key: str) -> str:
    """稳定、唯一、24 位十六进制的 Xcode 对象 ID。"""
    if key not in _ids:
        _counter[0] += 1
        _ids[key] = "A1%022X" % _counter[0]
    return _ids[key]


# --------------------------------------------------------------------------- #
# App 图标（纯标准库手写 PNG）
# --------------------------------------------------------------------------- #
def make_icon(path: Path) -> None:
    W = H = 1024
    buf = bytearray(W * H * 4)
    white = (255, 255, 255)
    blue = (24, 92, 216)

    def px(x: int, y: int, rgb, a: int = 255) -> None:
        if 0 <= x < W and 0 <= y < H:
            i = (y * W + x) * 4
            buf[i] = rgb[0]
            buf[i + 1] = rgb[1]
            buf[i + 2] = rgb[2]
            buf[i + 3] = a

    def rect(x0, y0, x1, y1, rgb, radius=0) -> None:
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                if radius:
                    cx = min(max(x, x0 + radius), x1 - radius - 1)
                    cy = min(max(y, y0 + radius), y1 - radius - 1)
                    if (x - cx) ** 2 + (y - cy) ** 2 > radius * radius:
                        continue
                px(x, y, rgb)

    def disc(cx, cy, r, rgb) -> None:
        for y in range(int(cy - r), int(cy + r)):
            for x in range(int(cx - r), int(cx + r)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px(x, y, rgb)

    # 蓝色渐变底
    for y in range(H):
        t = y / H
        col = (int(30 + 4 * t), int(104 - 30 * t), int(226 - 42 * t))
        for x in range(W):
            i = (y * W + x) * 4
            buf[i] = col[0]
            buf[i + 1] = col[1]
            buf[i + 2] = col[2]
            buf[i + 3] = 255

    # 证件卡片
    rect(162, 250, 862, 694, white, radius=56)
    # 头像
    disc(310, 400, 86, (218, 232, 250))
    disc(310, 380, 34, (150, 184, 232))
    disc(310, 466, 58, (150, 184, 232))
    # 信息条
    rect(440, 336, 800, 364, (206, 222, 244), radius=14)
    rect(440, 400, 760, 424, (224, 234, 250), radius=12)
    rect(440, 456, 790, 480, (224, 234, 250), radius=12)
    rect(200, 540, 824, 568, (232, 240, 252), radius=14)
    rect(200, 600, 660, 628, (232, 240, 252), radius=14)
    # 扫描取景框四角
    edge = (255, 255, 255)
    L, T, R, B, thick, arm = 200, 736, 824, 946, 18, 96
    for x0, y0, dx, dy in ((L, T, 1, 1), (R, T, -1, 1), (L, B, 1, -1), (R, B, -1, -1)):
        hx = x0 + dx * arm
        hy = y0 + dy * arm
        rect(min(x0, hx), min(y0, y0 + dy * thick), max(x0, hx) + thick, max(y0, y0 + dy * thick), edge)
        rect(min(x0, x0 + dx * thick), min(y0, hy), max(x0, x0 + dx * thick) + thick, max(y0, hy), edge)
    # 扫描线
    rect(240, 834, 784, 846, (255, 208, 96), radius=6)

    rows = [b"\x00" + bytes(buf[y * W * 4:(y + 1) * W * 4]) for y in range(H)]

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


# --------------------------------------------------------------------------- #
# pbxproj
# --------------------------------------------------------------------------- #
def build_pbxproj() -> str:
    swift_files = sorted(SOURCES.glob("*.swift"))
    if not swift_files:
        raise SystemExit("未找到 Sources/*.swift，请检查目录。")
    swift_names = [f.name for f in swift_files]

    refs: list[str] = []
    build_files: list[str] = []
    children: list[str] = []

    for name in swift_names:
        fid = oid("file:" + name)
        bid = oid("build:" + name)
        refs.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
        build_files.append(f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')
        children.append(f"\t\t\t\t{fid} /* {name} */,")

    plist_id = oid("file:Info.plist")
    refs.append(f'\t\t{plist_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    children.append(f"\t\t\t\t{plist_id} /* Info.plist */,")

    assets_id = oid("file:Assets.xcassets")
    assets_build = oid("build:Assets.xcassets")
    refs.append(f'\t\t{assets_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    children.append(f"\t\t\t\t{assets_id} /* Assets.xcassets */,")

    product_id = oid("product")
    refs.append(f'\t\t{product_id} /* {PRODUCT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PRODUCT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

    main_group = oid("group:main")
    src_group = oid("group:sources")
    products_group = oid("group:products")
    project = oid("project")
    target = oid("target")
    sources_phase = oid("phase:sources")
    frameworks_phase = oid("phase:frameworks")
    resources_phase = oid("phase:resources")
    proj_cfg_list = oid("list:project")
    target_cfg_list = oid("list:target")
    dbg_proj = oid("cfg:project:Debug")
    rel_proj = oid("cfg:project:Release")
    dbg_tgt = oid("cfg:target:Debug")
    rel_tgt = oid("cfg:target:Release")

    common_project = f'''\
		{dbg_proj} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{rel_proj} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Release;
		}};'''

    def target_cfg(name: str, ident: str) -> str:
        return f'''\
		{ident} /* {name} */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Sources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = {name};
		}};'''

    return f'''\
// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
		{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_id} /* Assets.xcassets */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group} = {{
			isa = PBXGroup;
			children = (
				{src_group} /* Sources */,
				{products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{src_group} /* Sources */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(children)}
			);
			path = Sources;
			sourceTree = "<group>";
		}};
		{products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_id} /* {PRODUCT_NAME}.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* {PRODUCT_NAME} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_cfg_list} /* Build configuration list for PBXNativeTarget "{PRODUCT_NAME}" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = {PRODUCT_NAME};
			productName = {PRODUCT_NAME};
			productReference = {product_id} /* {PRODUCT_NAME}.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{target} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject "{PRODUCT_NAME}" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
				"zh-Hans",
			);
			mainGroup = {main_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* {PRODUCT_NAME} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_build} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(f"				{oid('build:' + n)} /* {n} in Sources */," for n in swift_names)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{common_project}
{target_cfg("Debug", dbg_tgt)}
{target_cfg("Release", rel_tgt)}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{proj_cfg_list} /* Build configuration list for PBXProject "{PRODUCT_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{dbg_proj} /* Debug */,
				{rel_proj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_cfg_list} /* Build configuration list for PBXNativeTarget "{PRODUCT_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{dbg_tgt} /* Debug */,
				{rel_tgt} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
'''


def build_scheme() -> str:
    target = oid("target")
    return f'''\
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{PRODUCT_NAME}.app" BlueprintName="{PRODUCT_NAME}" ReferencedContainer="container:{PRODUCT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Release" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{PRODUCT_NAME}.app" BlueprintName="{PRODUCT_NAME}" ReferencedContainer="container:{PRODUCT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{PRODUCT_NAME}.app" BlueprintName="{PRODUCT_NAME}" ReferencedContainer="container:{PRODUCT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
'''


def main() -> None:
    SCHEMES.mkdir(parents=True, exist_ok=True)
    make_icon(ICONSET / "AppIcon.png")
    (ICONSET / "Contents.json").write_text('''{
  "images" : [{"filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024"}],
  "info" : {"author" : "xcode", "version" : 1}
}
''', encoding="utf-8")
    (SOURCES / "Assets.xcassets" / "Contents.json").write_text('''{
  "info" : {"author" : "xcode", "version" : 1}
}
''', encoding="utf-8")
    (PROJ / "project.pbxproj").write_text(build_pbxproj(), encoding="utf-8")
    (SCHEMES / f"{PRODUCT_NAME}.xcscheme").write_text(build_scheme(), encoding="utf-8")
    swift_count = len(list(SOURCES.glob("*.swift")))
    print(f"[OK] 已生成 {PROJ / 'project.pbxproj'}")
    print(f"[OK] 已生成 shared scheme、Assets.xcassets 与 AppIcon.png")
    print(f"[OK] 共收录 {swift_count} 个 Swift 源文件")


if __name__ == "__main__":
    main()
