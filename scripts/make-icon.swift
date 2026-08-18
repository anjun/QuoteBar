#!/usr/bin/env swift
import AppKit
import Foundation
import SwiftUI

// Sequoia (and earlier) shows CFBundleIconFile bitmaps as-is.
// System apps pre-compose the macOS icon grid: 824pt tile on a 1024
// canvas with continuous corners. Measured from Notes/Calculator icns:
// mid-edge inset = 100px at 1024. Apple's macOS 11+ template radius is 185.

let canvas: CGFloat = 1024
let tile: CGFloat = 824
let radius: CGFloat = 185
let glyph: CGFloat = 200

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("usage: make-icon.swift <out.png>\n", stderr)
    exit(1)
}

_ = NSApplication.shared

struct IconView: View {
    var body: some View {
        ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(.sRGB, red: 248 / 255, green: 249 / 255, blue: 251 / 255, opacity: 1))
                .frame(width: tile, height: tile)
                .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            Text("Q")
                .font(.system(size: glyph, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.sRGB, red: 226 / 255, green: 52 / 255, blue: 45 / 255, opacity: 1))
        }
        .frame(width: canvas, height: canvas)
    }
}

@MainActor
func render() -> CGImage {
    let renderer = ImageRenderer(content: IconView())
    renderer.proposedSize = ProposedViewSize(width: canvas, height: canvas)
    renderer.scale = 1
    renderer.isOpaque = false
    guard let cgImage = renderer.cgImage else {
        fputs("ImageRenderer failed to produce a CGImage\n", stderr)
        exit(2)
    }
    return cgImage
}

let cgImage = MainActor.assumeIsolated { render() }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
bitmap.size = NSSize(width: canvas, height: canvas)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(3)
}

do {
    try png.write(to: URL(fileURLWithPath: args[1]))
} catch {
    fputs("failed to write \(args[1]): \(error)\n", stderr)
    exit(4)
}
