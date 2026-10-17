// Draws the app icon (Ertaga kech): a green sparkle on a matte-black squircle, Apple 1024px grid. Usage: icon <out.png>
import AppKit

let size = 1024.0, body = 824.0, inset = (size - body) / 2
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.displayP3)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1) // top-left origin

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func round(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil) }

// Tile: soft shadow, then matte-black gradient
let tile = CGRect(x: inset, y: inset, width: body, height: body)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.28))
ctx.addPath(round(tile, 185)); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(round(tile, 185)); ctx.clip()
let bg = CGGradient(colorsSpace: nil, colors: [rgb(0x1C1C1C), rgb(0x050505)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: size / 2, y: inset), end: CGPoint(x: size / 2, y: inset + body), options: [])
// green light from the top-right and bottom-left, like the brand's light traces
let glow = CGGradient(colorsSpace: nil, colors: [rgb(0x3AD754, 0.45), rgb(0x3AD754, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: inset + body * 0.9, y: inset), startRadius: 0,
                       endCenter: CGPoint(x: inset + body * 0.9, y: inset), endRadius: body * 0.75, options: [])
let glow2 = CGGradient(colorsSpace: nil, colors: [rgb(0x3AD754, 0.2), rgb(0x3AD754, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow2, startCenter: CGPoint(x: inset, y: inset + body), startRadius: 0,
                       endCenter: CGPoint(x: inset, y: inset + body), endRadius: body * 0.6, options: [])
ctx.restoreGState()
// 1px-style top highlight
ctx.saveGState()
ctx.addPath(round(tile.insetBy(dx: 3, dy: 3), 182)); ctx.setLineWidth(6)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.08)); ctx.strokePath()
ctx.restoreGState()

// Glyph: a four-point sparkle (clean mark) with two small companions, one shape, filled with a light-to-brand green gradient
func sparkle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    let p = CGMutablePath(), k = r * 0.16 // control offset: smaller = sharper, more concave points
    let top = CGPoint(x: c.x, y: c.y - r), right = CGPoint(x: c.x + r, y: c.y)
    let bottom = CGPoint(x: c.x, y: c.y + r), left = CGPoint(x: c.x - r, y: c.y)
    p.move(to: top)
    p.addQuadCurve(to: right, control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: bottom, control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: left, control: CGPoint(x: c.x - k, y: c.y + k))
    p.addQuadCurve(to: top, control: CGPoint(x: c.x - k, y: c.y - k))
    p.closeSubpath()
    return p
}
let glyph = CGMutablePath()
glyph.addPath(sparkle(CGPoint(x: size / 2 - 40, y: size / 2 + 30), 290))
glyph.addPath(sparkle(CGPoint(x: size / 2 + 215, y: size / 2 - 215), 105))
glyph.addPath(sparkle(CGPoint(x: size / 2 + 190, y: size / 2 + 200), 62))
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: rgb(0x3AD754, 0.55))
ctx.addPath(glyph); ctx.setFillColor(rgb(0x3AD754)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(glyph); ctx.clip()
let wave = CGGradient(colorsSpace: nil, colors: [rgb(0x9CF2AB), rgb(0x3AD754)] as CFArray, locations: [0, 1])!
let box = glyph.boundingBox
ctx.drawLinearGradient(wave, start: CGPoint(x: box.midX, y: box.minY), end: CGPoint(x: box.midX, y: box.maxY), options: [])
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
