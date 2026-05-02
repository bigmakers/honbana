#!/usr/bin/swift
import AppKit
import CoreGraphics

// 「ホンダナ」アプリアイコン生成スクリプト
// 使い方: swift tools/generate_icon.swift BarcodeReview/Assets.xcassets/AppIcon.appiconset/AppIcon.png

let outputPath = CommandLine.arguments.count >= 2
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// ---- 背景 (温かみのあるクリーム → 暖かい黄土の縦グラデ) ----
let bg = CGGradient(
    colorsSpace: cs,
    colors: [color(255, 244, 224), color(245, 220, 188)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bg,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: 0, y: 0),
                       options: [])

// ---- 棚板 ----
let shelfY: CGFloat = 220
let shelfH: CGFloat = 50
ctx.setFillColor(color(120, 76, 50))
ctx.fill(CGRect(x: 80, y: shelfY, width: size - 160, height: shelfH))
// 棚板のハイライト
ctx.setFillColor(color(160, 105, 70))
ctx.fill(CGRect(x: 80, y: shelfY + shelfH - 10, width: size - 160, height: 6))

// ---- 本 ----
struct BookSpec {
    let x: CGFloat
    let width: CGFloat
    let height: CGFloat
    let tilt: CGFloat                    // 度
    let spineColor: CGColor
    let bandColor: CGColor
}

let books: [BookSpec] = [
    BookSpec(x: 200, width: 130, height: 560, tilt: 0,
             spineColor: color(190, 60, 60),
             bandColor: color(255, 220, 100)),
    BookSpec(x: 340, width: 110, height: 480, tilt: 0,
             spineColor: color(46, 110, 142),
             bandColor: color(240, 240, 230)),
    BookSpec(x: 460, width: 120, height: 600, tilt: 0,
             spineColor: color(70, 130, 80),
             bandColor: color(255, 230, 150)),
    BookSpec(x: 590, width: 100, height: 520, tilt: 0,
             spineColor: color(220, 150, 60),
             bandColor: color(110, 60, 30)),
    BookSpec(x: 700, width: 130, height: 560, tilt: -10,
             spineColor: color(120, 80, 140),
             bandColor: color(245, 245, 240))
]

let shelfTopY = shelfY + shelfH

for book in books {
    ctx.saveGState()

    let pivot = CGPoint(x: book.x + book.width/2, y: shelfTopY)
    ctx.translateBy(x: pivot.x, y: pivot.y)
    ctx.rotate(by: book.tilt * .pi / 180)
    ctx.translateBy(x: -pivot.x, y: -pivot.y)

    // 本体（背表紙）
    let rect = CGRect(x: book.x, y: shelfTopY, width: book.width, height: book.height)
    let bookPath = CGMutablePath()
    bookPath.addRoundedRect(in: rect, cornerWidth: 8, cornerHeight: 8)
    ctx.addPath(bookPath)
    ctx.setFillColor(book.spineColor)
    ctx.fillPath()

    // 上下の装飾バンド
    ctx.setFillColor(book.bandColor)
    ctx.fill(CGRect(x: book.x + 14, y: shelfTopY + book.height - 90,
                    width: book.width - 28, height: 12))
    ctx.fill(CGRect(x: book.x + 14, y: shelfTopY + 60,
                    width: book.width - 28, height: 8))

    // タイトル代わりの斜めライン
    ctx.setFillColor(book.bandColor)
    ctx.fill(CGRect(x: book.x + book.width/2 - 8,
                    y: shelfTopY + book.height/2 - 100,
                    width: 16, height: 200))

    // 右端のハイライトで立体感
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
    ctx.fill(CGRect(x: book.x + book.width - 10, y: shelfTopY,
                    width: 10, height: book.height))

    ctx.restoreGState()
}

// ---- アクセント: 棚の影 ----
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
ctx.fill(CGRect(x: 80, y: shelfY - 14, width: size - 160, height: 14))

guard let cgImage = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }

let outURL = URL(fileURLWithPath: outputPath)
try png.write(to: outURL)
print("Wrote \(outURL.path) (\(png.count) bytes)")
