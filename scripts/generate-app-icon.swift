#!/usr/bin/env swift
//
// generate-app-icon.swift
//
// Generates the 1024x1024 app icon as a PNG using CoreGraphics (no
// third-party deps; no AppKit, no ImageIO format conversion roulette).
//
// The icon is "·−" — Morse for the letter A — rendered in amber `#FFA500`
// (the same colour the HUD uses for highlights, FR-14) on pure black.
// "·−" reads visually as a flashlight beam coming from a bulb, fitting
// the beacon concept without being literal about it.
//
// Output: MorseBeacon/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// Usage:
//   ./scripts/generate-app-icon.swift
//
// Run again whenever the icon design changes.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let canvas = CGRect(x: 0, y: 0, width: size, height: size)

guard
  let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
  FileHandle.standardError.write("Failed to create CGContext\n".data(using: .utf8)!)
  exit(1)
}

// Pure black background. Matches the BeaconView's flash-off colour and
// the SafetyWarningView background.
context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.fill(canvas)

// Amber #FFA500 — Theme.hudHighlightBackground.
let amber = CGColor(red: 1.0, green: 0.647, blue: 0.0, alpha: 1.0)
context.setFillColor(amber)

// Layout: dot then dash, both centred vertically. Total horizontal extent
// occupies ~70% of the canvas with healthy padding so the squircle mask
// iOS applies on the home screen doesn't crop the symbols.
let centreY = CGFloat(size) / 2

// Dit (dot)
let dotRadius: CGFloat = 130
let dotCentreX: CGFloat = 280
let dotRect = CGRect(
  x: dotCentreX - dotRadius,
  y: centreY - dotRadius,
  width: dotRadius * 2,
  height: dotRadius * 2)
context.fillEllipse(in: dotRect)

// Dah (dash)
let dashWidth: CGFloat = 480
let dashHeight: CGFloat = 200
let dashStartX: CGFloat = 480
let dashRect = CGRect(
  x: dashStartX,
  y: centreY - dashHeight / 2,
  width: dashWidth,
  height: dashHeight)
let dashPath = CGPath(
  roundedRect: dashRect,
  cornerWidth: dashHeight / 2,
  cornerHeight: dashHeight / 2,
  transform: nil)
context.addPath(dashPath)
context.fillPath()

guard let image = context.makeImage() else {
  FileHandle.standardError.write("Failed to render image\n".data(using: .utf8)!)
  exit(1)
}

// Resolve output path relative to the script's location so the script can
// be invoked from any working directory.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputURL = repoRoot
  .appendingPathComponent("MorseBeacon")
  .appendingPathComponent("Assets.xcassets")
  .appendingPathComponent("AppIcon.appiconset")
  .appendingPathComponent("icon-1024.png")

guard
  let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil)
else {
  FileHandle.standardError.write(
    "Failed to create image destination at \(outputURL.path)\n".data(using: .utf8)!)
  exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
  FileHandle.standardError.write("Failed to finalize PNG\n".data(using: .utf8)!)
  exit(1)
}

print("Wrote \(outputURL.path)")
