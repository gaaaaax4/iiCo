#!/usr/bin/env swift

// iiCo アプリアイコン生成スクリプト
// 出力: Sources/iiCo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import AppKit
import CoreGraphics
import CoreText

let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "./Sources/iiCo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// MARK: - Canvas

let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// MARK: - Background（#fffffe）
cg.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 0.996, alpha: 1.0))
cg.fill(rect)

// MARK: - 円ボタン（#6246ea）
let circleSize = CGFloat(size) * 0.72
let circleX = (CGFloat(size) - circleSize) / 2
let circleY = (CGFloat(size) - circleSize) / 2
let circleRect = CGRect(x: circleX, y: circleY, width: circleSize, height: circleSize)

// ドロップシャドウ
cg.setShadow(
    offset: CGSize(width: 0, height: -CGFloat(size) * 0.015),
    blur: CGFloat(size) * 0.04,
    color: CGColor(red: 0.384, green: 0.275, blue: 0.918, alpha: 0.35)
)
cg.setFillColor(CGColor(red: 0.384, green: 0.275, blue: 0.918, alpha: 1.0)) // #6246ea
cg.fillEllipse(in: circleRect)
cg.setShadow(offset: .zero, blur: 0, color: nil) // シャドウリセット

// MARK: - "iiCo" テキスト
let textSize = CGFloat(size) * 0.20
let font = NSFont.boldSystemFont(ofSize: textSize)
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(red: 1.0, green: 1.0, blue: 0.996, alpha: 1.0), // #fffffe
]
let text = NSAttributedString(string: "iiCo", attributes: textAttrs)
let textSz = text.size()
let textX = (CGFloat(size) - textSz.width) / 2
// 円の中心に合わせる
let textY = circleY + (circleSize - textSz.height) / 2
text.draw(at: CGPoint(x: textX, y: textY))

// MARK: - 書き出し
let pngData = bitmapRep.representation(using: .png, properties: [:])!
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✅ アイコン生成完了: \(outputPath)")
    print("   サイズ: \(pngData.count / 1024) KB")
} catch {
    print("❌ 書き込み失敗: \(error)")
    exit(1)
}
