#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets",
    isDirectory: true
)
let iconset = outputDirectory.appending(
    path: "AppIcon.iconset",
    directoryHint: .isDirectory
)
let fileManager = FileManager.default
try fileManager.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)
if fileManager.fileExists(atPath: iconset.path) {
    try fileManager.removeItem(at: iconset)
}
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func roundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 0
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke, lineWidth > 0 {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func circle(_ rect: NSRect, fill: NSColor) {
    let path = NSBezierPath(ovalIn: rect)
    fill.setFill()
    path.fill()
}

func drawIcon() {
    let charcoal = color(0x171A1D)
    let panel = color(0xF4F7F8)
    let ink = color(0x172126)
    let muted = color(0xDCE6E8)
    let teal = color(0x0F8B8D)
    let amber = color(0xE88700)
    let coral = color(0xE64B4F)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowBlurRadius = 32
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    roundedRect(
        NSRect(x: 54, y: 64, width: 916, height: 916),
        radius: 210,
        fill: charcoal
    )
    NSShadow().set()
    roundedRect(
        NSRect(x: 72, y: 82, width: 880, height: 880),
        radius: 194,
        fill: charcoal,
        stroke: color(0x3A4145),
        lineWidth: 8
    )

    roundedRect(
        NSRect(x: 158, y: 220, width: 708, height: 594),
        radius: 82,
        fill: panel
    )
    let sidebar = NSBezierPath(
        roundedRect: NSRect(x: 158, y: 220, width: 222, height: 594),
        xRadius: 82,
        yRadius: 82
    )
    muted.setFill()
    sidebar.fill()
    panel.setFill()
    NSRect(x: 298, y: 220, width: 82, height: 594).fill()
    color(0xB7C8CB).setFill()
    NSRect(x: 374, y: 220, width: 8, height: 594).fill()

    roundedRect(NSRect(x: 208, y: 694, width: 118, height: 24), radius: 12, fill: ink)
    roundedRect(NSRect(x: 208, y: 624, width: 92, height: 20), radius: 10, fill: teal)
    circle(NSRect(x: 204, y: 548, width: 28, height: 28), fill: amber)
    roundedRect(NSRect(x: 246, y: 552, width: 82, height: 20), radius: 10, fill: ink)
    circle(NSRect(x: 204, y: 472, width: 28, height: 28), fill: coral)
    roundedRect(NSRect(x: 246, y: 476, width: 56, height: 20), radius: 10, fill: color(0x758489))
    roundedRect(NSRect(x: 204, y: 338, width: 124, height: 22), radius: 11, fill: color(0x758489))
    roundedRect(NSRect(x: 204, y: 294, width: 86, height: 22), radius: 11, fill: ink)

    let antenna = NSBezierPath()
    antenna.move(to: NSPoint(x: 622, y: 708))
    antenna.line(to: NSPoint(x: 622, y: 772))
    antenna.lineWidth = 14
    antenna.lineCapStyle = .round
    ink.setStroke()
    antenna.stroke()
    circle(NSRect(x: 601, y: 758, width: 42, height: 42), fill: amber)

    roundedRect(
        NSRect(x: 456, y: 338, width: 332, height: 370),
        radius: 62,
        fill: color(0xE7EFF0),
        stroke: teal,
        lineWidth: 18
    )
    roundedRect(
        NSRect(x: 506, y: 474, width: 232, height: 130),
        radius: 34,
        fill: ink
    )
    circle(NSRect(x: 544, y: 520, width: 48, height: 48), fill: teal)
    circle(NSRect(x: 652, y: 520, width: 48, height: 48), fill: amber)

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 584, y: 504))
    smile.curve(
        to: NSPoint(x: 660, y: 504),
        controlPoint1: NSPoint(x: 602, y: 474),
        controlPoint2: NSPoint(x: 642, y: 474)
    )
    smile.lineWidth = 12
    smile.lineCapStyle = .round
    panel.setStroke()
    smile.stroke()

    roundedRect(NSRect(x: 488, y: 294, width: 96, height: 48), radius: 18, fill: ink)
    roundedRect(NSRect(x: 660, y: 294, width: 96, height: 48), radius: 18, fill: ink)
    roundedRect(NSRect(x: 500, y: 242, width: 54, height: 26), radius: 10, fill: teal)
    roundedRect(NSRect(x: 594, y: 242, width: 54, height: 26), radius: 10, fill: amber)
    roundedRect(NSRect(x: 688, y: 242, width: 54, height: 26), radius: 10, fill: coral)
}

func pngData(size: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
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
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
        NSGraphicsContext.restoreGraphicsState()
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, size) in variants {
    try pngData(size: size).write(to: iconset.appending(path: name))
}
try pngData(size: 1024).write(to: outputDirectory.appending(path: "AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "--convert", "icns",
    "--output", outputDirectory.appending(path: "AppIcon.icns").path,
    iconset.path,
]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}
try fileManager.removeItem(at: iconset)
