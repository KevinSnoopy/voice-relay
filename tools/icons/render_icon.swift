// VoiceRelay 应用图标渲染器（唯一图形真源）。
// 用法: swift tools/icons/render_icon.swift <out.png> <size> <mode>
//   mode: mac      1024 方图里的圆角方形（macOS AppIcon 网格：留 9.8% 边距）
//         ios      满幅方形 + 无 alpha（系统自己切圆角）
//         android  圆角方形（旧版 launcher PNG）
//         adaptive 只画麦克风，透明底（Android 自适应图标前景）
import AppKit
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count == 4, let size = Int(args[2]) else {
    FileHandle.standardError.write("usage: render_icon <out.png> <size> <mac|ios|android|adaptive>\n".data(using: .utf8)!)
    exit(2)
}
let outPath = args[1]
let mode = args[3]
let S = CGFloat(size)

// —— 麦克风造型（归一化坐标，y 向上，原点在图形框左下角）——
// 数值集中在这里，改造型只改这一处。
let capsuleHalfWidth: CGFloat = 0.175
let capsuleBottom: CGFloat = 0.55
let capsuleTop: CGFloat = 0.99
let cradleCenterY: CGFloat = 0.62
let cradleRadius: CGFloat = 0.28
let cradleStroke: CGFloat = 0.12
let stemTop: CGFloat = 0.32
let stemBottom: CGFloat = 0.12
let baseHalfWidth: CGFloat = 0.17
let stemWidth: CGFloat = 0.12
// 图形实际占位（用于居中缩放）
let visualLeft: CGFloat = 0.5 - cradleRadius - cradleStroke / 2
let visualRight: CGFloat = 0.5 + cradleRadius + cradleStroke / 2
let visualBottom: CGFloat = stemBottom - stemWidth / 2
let visualTop: CGFloat = capsuleTop
let visualHeight = visualTop - visualBottom

func micPath(in ctx: CGContext, box: CGRect, glyphHeightRatio: CGFloat) {
    let s = box.height * glyphHeightRatio / visualHeight
    ctx.saveGState()
    ctx.translateBy(x: box.midX - 0.5 * s, y: box.midY - (visualTop + visualBottom) / 2 * s)
    ctx.scaleBy(x: s, y: s)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // 麦克风主体（胶囊）
    let capsule = CGRect(x: 0.5 - capsuleHalfWidth, y: capsuleBottom,
                         width: capsuleHalfWidth * 2, height: capsuleTop - capsuleBottom)
    ctx.addPath(CGPath(roundedRect: capsule, cornerWidth: capsuleHalfWidth, cornerHeight: capsuleHalfWidth, transform: nil))
    ctx.fillPath()

    // 托架（下半圆）
    ctx.setLineWidth(cradleStroke)
    ctx.addArc(center: CGPoint(x: 0.5, y: cradleCenterY), radius: cradleRadius,
               startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()

    // 支架 + 底座（≤24px 时底座糊成一团，去掉）
    ctx.setLineWidth(stemWidth)
    ctx.move(to: CGPoint(x: 0.5, y: stemTop))
    ctx.addLine(to: CGPoint(x: 0.5, y: stemBottom))
    if S > 24 {
        ctx.move(to: CGPoint(x: 0.5 - baseHalfWidth, y: stemBottom))
        ctx.addLine(to: CGPoint(x: 0.5 + baseHalfWidth, y: stemBottom))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

func bodyRect(_ mode: String, _ S: CGFloat) -> (CGRect, CGFloat)? {
    switch mode {
    case "mac":
        // macOS AppIcon 网格：形状 824/1024，圆角 22.5%
        let inset = S * 0.098
        return (CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2), 0.225)
    case "ios":
        return (CGRect(x: 0, y: 0, width: S, height: S), 0)
    case "android":
        let inset = S * 0.03
        return (CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2), 0.20)
    default:
        return nil
    }
}

let cs = CGColorSpaceCreateDeviceRGB()
let opaque = (mode == "ios")
let ctx = CGContext(data: nil,
                    width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: opaque ? CGImageAlphaInfo.noneSkipLast.rawValue
                                       : CGImageAlphaInfo.premultipliedLast.rawValue)!

let white = CGColor(colorSpace: cs, components: [1, 1, 1, 1])!
let topColor = CGColor(colorSpace: cs, components: [59.0 / 255, 130.0 / 255, 246.0 / 255, 1])!
let bottomColor = CGColor(colorSpace: cs, components: [30.0 / 255, 64.0 / 255, 175.0 / 255, 1])!

if let (body, cornerRatio) = bodyRect(mode, S) {
    let path = CGPath(roundedRect: body, cornerWidth: body.width * cornerRatio,
                      cornerHeight: body.width * cornerRatio, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [topColor, bottomColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: body.minX, y: body.maxY),
                            end: CGPoint(x: body.maxX, y: body.minY), options: [])
    // 左上柔光
    let hl = CGGradient(colorsSpace: cs,
                        colors: [CGColor(colorSpace: cs, components: [1, 1, 1, 0.20])!,
                                 CGColor(colorSpace: cs, components: [1, 1, 1, 0])!] as CFArray,
                        locations: [0, 1])!
    let c = CGPoint(x: body.minX + body.width * 0.28, y: body.maxY - body.height * 0.26)
    ctx.drawRadialGradient(hl, startCenter: c, startRadius: 0,
                           endCenter: c, endRadius: body.width * 0.72, options: [])
    ctx.restoreGState()

    // 麦克风：落在内切圆里，四周留白
    let glyphBox = body.insetBy(dx: body.width * 0.16, dy: body.height * 0.16)
    ctx.setFillColor(white)
    ctx.setStrokeColor(white)
    micPath(in: ctx, box: glyphBox, glyphHeightRatio: 0.86)
} else {
    // adaptive：只画麦克风，安全区 66/108
    let glyphBox = CGRect(x: 0, y: 0, width: S, height: S)
    ctx.setFillColor(white)
    ctx.setStrokeColor(white)
    micPath(in: ctx, box: glyphBox, glyphHeightRatio: 0.48)
}

guard let image = ctx.makeImage() else { fatalError("makeImage failed") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("cannot create \(outPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("cannot write \(outPath)") }
