# outcome: failure
# commit: 93121290d71f4088c76bbe706cc23584015c2d1c
# time: 2026-11-26T15:34:32Z

----- errors -----
** BUILD SUCCEEDED **
::error::构建失败（1），命令：codesign --verify --strict --verbose=4 "Payload/FlyMe2theMoon.app" > verify2.out 2>&1

----- tail -----
ExtractAppIntentsMetadata (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor --toolchain-dir /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --module-name FlyMe2theMoon --sdk-root /Applications/Xcode_16.4.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk --xcode-version 16F6 --platform-family iOS --deployment-target 16.0 --bundle-identifier com.mihoyo.flyme2themoon.arm64 --output /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app --target-triple arm64-apple-ios16.0 --binary-file /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/FlyMe2theMoon --dependency-file /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/Objects-normal/arm64/FlyMe2theMoon_dependency_info.dat --stringsdata-file /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/Objects-normal/arm64/ExtractedAppShortcutsMetadata.stringsdata --source-file-list /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/Objects-normal/arm64/FlyMe2theMoon.SwiftFileList --metadata-file-list /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/FlyMe2theMoon.DependencyMetadataFileList --static-metadata-file-list /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/FlyMe2theMoon.DependencyStaticMetadataFileList --swift-const-vals-list /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/Objects-normal/arm64/FlyMe2theMoon.SwiftConstValuesFileList --compile-time-extraction --deployment-aware-processing --validate-assistant-intents --no-app-shortcuts-localization
2026-11-26 15:34:29.576 appintentsmetadataprocessor[1748:8186] Starting appintentsmetadataprocessor export
2026-11-26 15:34:29.578 appintentsmetadataprocessor[1748:8186] warning: Metadata extraction skipped. No AppIntents.framework dependency found.

GenerateDSYMFile /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app.dSYM /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/FlyMe2theMoon (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/dsymutil /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/FlyMe2theMoon -o /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app.dSYM

AppIntentsSSUTraining (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor --infoplist-path /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/Info.plist --temp-dir-path /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/ssu --bundle-id com.mihoyo.flyme2themoon.arm64 --product-path /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app --extracted-metadata-path /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/Metadata.appintents --metadata-file-list /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Intermediates.noindex/FlyMe2theMoon.build/Release-iphoneos/FlyMe2theMoon.build/FlyMe2theMoon.DependencyMetadataFileList --archive-ssu-assets
2026-11-26 15:34:29.603 appintentsnltrainingprocessor[1751:8192] Parsing options for appintentsnltrainingprocessor
2026-11-26 15:34:29.604 appintentsnltrainingprocessor[1751:8192] No AppShortcuts found - Skipping.

RegisterExecutionPolicyException /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    builtin-RegisterExecutionPolicyException /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app

Validate /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    builtin-validationUtility /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app -infoplist-subpath Info.plist

Touch /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
    cd /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64
    /usr/bin/touch -c /Users/runner/work/flyme2themoon_iOS_arm64/flyme2themoon_iOS_arm64/build/Build/Products/Release-iphoneos/FlyMe2theMoon.app

note: Disabling previews because SWIFT_VERSION is set and SWIFT_OPTIMIZATION_LEVEL=-O, expected -Onone (in target 'FlyMe2theMoon' from project 'FlyMe2theMoon')
** BUILD SUCCEEDED **

xcodebuild exit=0

===== 校验产物 =====
Non-fat file: build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/FlyMe2theMoon is architecture: arm64
FlyMe2theMoon: Non-fat file: build/Build/Products/Release-iphoneos/FlyMe2theMoon.app/FlyMe2theMoon is architecture: arm64
  "CFBundleExecutable" => "FlyMe2theMoon"
  "CFBundleIdentifier" => "com.mihoyo.flyme2themoon.arm64"
  "MinimumOSVersion" => "16.0"

===== 模拟器冒烟测试（建议性） =====
模拟器冒烟测试：默认跳过（设置 SIM_SMOKE=1 启用）

===== 打包 IPA =====
codesign exit=0  codesign --verify exit=0
--- codesign 输出 ---
--- codesign --verify ---
Payload/FlyMe2theMoon.app: valid on disk
Payload/FlyMe2theMoon.app: satisfies its Designated Requirement
--- CodeDirectory 概览 ---
Identifier=com.mihoyo.flyme2themoon.arm64
Format=bundle with Mach-O thin (arm64)
CodeDirectory v=20400 size=7831 flags=0x2(adhoc) hashes=238+3 location=embedded
CandidateCDHash sha256=f43b92118547b2b734f77098d6ef5a6d2fd0dc94
CandidateCDHashFull sha256=f43b92118547b2b734f77098d6ef5a6d2fd0dc94bee535924967ebe6507c8501
CDHash=f43b92118547b2b734f77098d6ef5a6d2fd0dc94
Signature=adhoc
TeamIdentifier=not set
Sealed Resources version=2 rules=13 files=177
sha256(Info.plist)=36a364135141739babcaf89f4e0f9d80a82478862a2113e364c7878d692efd7a
--- 补写前：codesign 特殊槽 ---
Info.plist=not bound
CodeDirectory: ident=com.mihoyo.flyme2themoon.arm64 version=0x20400 flags=0x2 len=7831 nSpecial=3 nCode=238 codeLimit=972112 hashSize=32
分页哈希：0/238 不一致
special slots（共 3 个）:
  slot 1 (Info.plist): ZERO
  slot 2 (Requirements): 987920904eab650e…
  slot 3 (CodeResources): f11a26a2107eb778…
Info.plist 槽：不一致
CodeResources 槽：一致（45356 字节）
cdhash(sha256) = f43b92118547b2b734f77098d6ef5a6d2fd0dc94
flags: ad-hoc（无开发者证书）
!! 签名自洽性校验失败：Info.plist 槽不一致
Info.plist sha256 = 36a364135141739babcaf89f4e0f9d80a82478862a2113e364c7878d692efd7a
slot -1 现值      = 0000000000000000000000000000000000000000000000000000000000000000
分页哈希复核：0/238 不一致
已写入 slot -1，CodeDirectory 长度不变（7831 字节）
--- 补写后：codesign 特殊槽 ---
Info.plist=not bound
::error::构建失败（1），命令：codesign --verify --strict --verbose=4 "Payload/FlyMe2theMoon.app" > verify2.out 2>&1
