import AppKit
import AVFoundation
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : "public/videos/proof-flow.mp4"

let width = 1280
let height = 720
let fps = 30
let durationSeconds = 12
let totalFrames = fps * durationSeconds
let outputURL = URL(fileURLWithPath: outputPath)

try? FileManager.default.removeItem(at: outputURL)

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
  AVVideoCodecKey: AVVideoCodecType.h264,
  AVVideoWidthKey: width,
  AVVideoHeightKey: height,
  AVVideoCompressionPropertiesKey: [
    AVVideoAverageBitRateKey: 4_500_000,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
  ],
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false

let attributes: [String: Any] = [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
  kCVPixelBufferWidthKey as String: width,
  kCVPixelBufferHeightKey as String: height,
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
  assetWriterInput: input,
  sourcePixelBufferAttributes: attributes
)

guard writer.canAdd(input) else {
  fatalError("Cannot add video input")
}
writer.add(input)
guard writer.startWriting() else {
  fatalError("Cannot start writer: \(writer.error?.localizedDescription ?? "unknown")")
}
writer.startSession(atSourceTime: .zero)

let navy = NSColor(red: 15 / 255, green: 45 / 255, blue: 75 / 255, alpha: 1)
let sky = NSColor(red: 15 / 255, green: 150 / 255, blue: 195 / 255, alpha: 1)
let teal = NSColor(red: 0 / 255, green: 105 / 255, blue: 105 / 255, alpha: 1)
let emerald = NSColor(red: 30 / 255, green: 165 / 255, blue: 105 / 255, alpha: 1)
let gold = NSColor(red: 240 / 255, green: 195 / 255, blue: 30 / 255, alpha: 1)
let orange = NSColor(red: 240 / 255, green: 150 / 255, blue: 60 / 255, alpha: 1)
let coral = NSColor(red: 240 / 255, green: 105 / 255, blue: 90 / 255, alpha: 1)
let paper = NSColor(red: 247 / 255, green: 250 / 255, blue: 252 / 255, alpha: 1)
let ink = NSColor(red: 15 / 255, green: 45 / 255, blue: 75 / 255, alpha: 1)

func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
  let left = a.usingColorSpace(.deviceRGB)!
  let right = b.usingColorSpace(.deviceRGB)!
  return NSColor(
    red: left.redComponent + (right.redComponent - left.redComponent) * t,
    green: left.greenComponent + (right.greenComponent - left.greenComponent) * t,
    blue: left.blueComponent + (right.blueComponent - left.blueComponent) * t,
    alpha: left.alphaComponent + (right.alphaComponent - left.alphaComponent) * t
  )
}

func ease(_ value: CGFloat) -> CGFloat {
  if value <= 0 { return 0 }
  if value >= 1 { return 1 }
  return 1 - pow(1 - value, 3)
}

func drawText(
  _ text: String,
  in rect: CGRect,
  size: CGFloat,
  weight: NSFont.Weight = .regular,
  color: NSColor = ink,
  alignment: NSTextAlignment = .left
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = alignment
  paragraph.lineSpacing = 4
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size, weight: weight),
    .foregroundColor: color,
    .paragraphStyle: paragraph,
  ]
  NSAttributedString(string: text, attributes: attributes).draw(in: rect)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
  color.setFill()
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat = 2) {
  color.setStroke()
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
  path.lineWidth = width
  path.stroke()
}

func drawCapsule(_ text: String, rect: CGRect, color: NSColor, textColor: NSColor = .white) {
  fillRounded(rect, radius: rect.height / 2, color: color)
  drawText(text, in: rect.insetBy(dx: 18, dy: 8), size: 23, weight: .semibold, color: textColor, alignment: .center)
}

func drawIconCard(_ title: String, subtitle: String, rect: CGRect, accent: NSColor, index: Int) {
  fillRounded(rect, radius: 26, color: NSColor.white.withAlphaComponent(0.92))
  strokeRounded(rect, radius: 26, color: accent.withAlphaComponent(0.35), width: 2)
  fillRounded(CGRect(x: rect.minX + 24, y: rect.minY + rect.height - 88, width: 58, height: 58), radius: 16, color: accent.withAlphaComponent(0.16))
  drawText("\(index)", in: CGRect(x: rect.minX + 24, y: rect.minY + rect.height - 81, width: 58, height: 42), size: 30, weight: .bold, color: accent, alignment: .center)
  drawText(title, in: CGRect(x: rect.minX + 98, y: rect.minY + rect.height - 76, width: rect.width - 122, height: 36), size: 28, weight: .bold, color: ink)
  drawText(subtitle, in: CGRect(x: rect.minX + 28, y: rect.minY + 34, width: rect.width - 56, height: 78), size: 22, weight: .medium, color: ink.withAlphaComponent(0.72))
}

func drawBackground(_ context: CGContext, time: CGFloat) {
  let steps = 36
  for step in 0..<steps {
    let t = CGFloat(step) / CGFloat(steps - 1)
    let color = mix(mix(navy, teal, t), mix(sky, gold, t), 0.18 + 0.08 * sin(time * 0.8))
    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: CGFloat(step) * CGFloat(width) / CGFloat(steps), y: 0, width: CGFloat(width) / CGFloat(steps) + 1, height: CGFloat(height)))
  }
  NSColor.white.withAlphaComponent(0.08).setFill()
  NSBezierPath(ovalIn: CGRect(x: 880 + sin(time) * 22, y: 430, width: 440, height: 440)).fill()
  NSColor.white.withAlphaComponent(0.06).setFill()
  NSBezierPath(ovalIn: CGRect(x: -120, y: -100 + cos(time) * 18, width: 360, height: 360)).fill()
}

func drawTimeline(_ progress: CGFloat) {
  let labels = ["Capability", "Mission", "Session", "Evidence", "Review", "Portfolio", "Growth Report"]
  let x0: CGFloat = 110
  let x1: CGFloat = 1170
  let y: CGFloat = 112
  let activeWidth = (x1 - x0) * progress
  NSColor.white.withAlphaComponent(0.24).setStroke()
  let base = NSBezierPath()
  base.move(to: CGPoint(x: x0, y: y))
  base.line(to: CGPoint(x: x1, y: y))
  base.lineWidth = 6
  base.stroke()
  sky.setStroke()
  let active = NSBezierPath()
  active.move(to: CGPoint(x: x0, y: y))
  active.line(to: CGPoint(x: x0 + activeWidth, y: y))
  active.lineWidth = 6
  active.stroke()
  for (index, label) in labels.enumerated() {
    let x = x0 + (x1 - x0) * CGFloat(index) / CGFloat(labels.count - 1)
    let isActive = progress >= CGFloat(index) / CGFloat(labels.count - 1) - 0.01
    let color = isActive ? sky : NSColor.white.withAlphaComponent(0.48)
    fillRounded(CGRect(x: x - 16, y: y - 16, width: 32, height: 32), radius: 16, color: color)
    drawText(label, in: CGRect(x: x - 72, y: y - 58, width: 144, height: 32), size: 15, weight: .semibold, color: .white, alignment: .center)
  }
}

func drawFrame(_ frameIndex: Int, in context: CGContext) {
  let time = CGFloat(frameIndex) / CGFloat(fps)
  drawBackground(context, time: time)
  drawText("SCHOLESA", in: CGRect(x: 70, y: 635, width: 220, height: 36), size: 24, weight: .bold, color: .white)
  drawText("Bright Future. Serious Learning.", in: CGRect(x: 900, y: 636, width: 310, height: 34), size: 20, weight: .semibold, color: .white.withAlphaComponent(0.82), alignment: .right)
  drawTimeline(min(1, time / CGFloat(durationSeconds)))

  if time < 2.4 {
    let a = ease(time / 1.0)
    drawText("The Proof Flow", in: CGRect(x: 96, y: 430 + (1 - a) * 24, width: 760, height: 84), size: 70, weight: .heavy, color: .white)
    drawText("From studio moments to trustworthy capability growth.", in: CGRect(x: 100, y: 374, width: 760, height: 44), size: 30, weight: .medium, color: .white.withAlphaComponent(0.84))
    drawCapsule("capability -> mission -> session", rect: CGRect(x: 100, y: 300, width: 410, height: 52), color: sky)
    drawCapsule("evidence -> portfolio -> growth report", rect: CGRect(x: 530, y: 300, width: 500, height: 52), color: emerald)
  } else if time < 4.8 {
    drawText("1. Capture Evidence", in: CGRect(x: 80, y: 560, width: 760, height: 58), size: 48, weight: .heavy, color: .white)
    drawIconCard("Observe", subtitle: "Educator logs a real studio moment in seconds.", rect: CGRect(x: 90, y: 250, width: 330, height: 230), accent: sky, index: 1)
    drawIconCard("Artifact", subtitle: "Learner work, media, and reflection stay attached.", rect: CGRect(x: 475, y: 250, width: 330, height: 230), accent: gold, index: 2)
    drawIconCard("Context", subtitle: "Mission, session, and capability nodes travel with it.", rect: CGRect(x: 860, y: 250, width: 330, height: 230), accent: emerald, index: 3)
  } else if time < 7.2 {
    drawText("2. Verify Authenticity", in: CGRect(x: 80, y: 560, width: 840, height: 58), size: 48, weight: .heavy, color: .white)
    fillRounded(CGRect(x: 105, y: 258, width: 470, height: 240), radius: 30, color: paper.withAlphaComponent(0.94))
    drawText("Evidence Review", in: CGRect(x: 145, y: 430, width: 360, height: 42), size: 34, weight: .bold, color: ink)
    drawText("Rubric judgment\nAI-use disclosure\nTimestamp + role trail", in: CGRect(x: 145, y: 304, width: 340, height: 100), size: 27, weight: .medium, color: ink.withAlphaComponent(0.76))
    fillRounded(CGRect(x: 660, y: 258, width: 470, height: 240), radius: 30, color: paper.withAlphaComponent(0.94))
    drawText("Auditable Proof", in: CGRect(x: 700, y: 430, width: 360, height: 42), size: 34, weight: .bold, color: ink)
    drawText("Who observed it\nWhat artifact supports it\nWhy growth changed", in: CGRect(x: 700, y: 304, width: 360, height: 100), size: 27, weight: .medium, color: ink.withAlphaComponent(0.76))
  } else if time < 9.6 {
    drawText("3. Map Growth", in: CGRect(x: 80, y: 560, width: 760, height: 58), size: 48, weight: .heavy, color: .white)
    let nodes: [(CGFloat, CGFloat, CGFloat, NSColor, String)] = [
      (235, 370, 74, sky, "Future\nSkills"),
      (430, 450, 60, emerald, "Lead"),
      (590, 330, 86, gold, "Impact"),
      (790, 438, 68, orange, "Explain"),
      (980, 330, 78, coral, "Improve"),
    ]
    NSColor.white.withAlphaComponent(0.36).setStroke()
    for i in 0..<(nodes.count - 1) {
      let p = NSBezierPath()
      p.move(to: CGPoint(x: nodes[i].0, y: nodes[i].1))
      p.line(to: CGPoint(x: nodes[i + 1].0, y: nodes[i + 1].1))
      p.lineWidth = 4
      p.stroke()
    }
    for node in nodes {
      fillRounded(CGRect(x: node.0 - node.2 / 2, y: node.1 - node.2 / 2, width: node.2, height: node.2), radius: node.2 / 2, color: node.3)
      drawText(node.4, in: CGRect(x: node.0 - 64, y: node.1 - 24, width: 128, height: 54), size: 20, weight: .bold, color: node.3 == gold ? navy : .white, alignment: .center)
    }
  } else {
    drawText("4. Portfolio-Ready Proof", in: CGRect(x: 80, y: 560, width: 880, height: 58), size: 48, weight: .heavy, color: .white)
    fillRounded(CGRect(x: 95, y: 248, width: 330, height: 255), radius: 30, color: paper.withAlphaComponent(0.94))
    drawText("Portfolio", in: CGRect(x: 130, y: 438, width: 250, height: 42), size: 35, weight: .bold, color: ink)
    drawText("Artifacts and reflections become a showcase learners can explain.", in: CGRect(x: 130, y: 306, width: 250, height: 96), size: 24, weight: .medium, color: ink.withAlphaComponent(0.76))
    fillRounded(CGRect(x: 475, y: 248, width: 330, height: 255), radius: 30, color: paper.withAlphaComponent(0.94))
    drawText("Badge", in: CGRect(x: 510, y: 438, width: 250, height: 42), size: 35, weight: .bold, color: ink)
    drawText("Capability signals connect to real evidence, not averages.", in: CGRect(x: 510, y: 306, width: 250, height: 96), size: 24, weight: .medium, color: ink.withAlphaComponent(0.76))
    fillRounded(CGRect(x: 855, y: 248, width: 330, height: 255), radius: 30, color: paper.withAlphaComponent(0.94))
    drawText("Growth Report", in: CGRect(x: 890, y: 438, width: 260, height: 42), size: 35, weight: .bold, color: ink)
    drawText("Families see what changed, why it matters, and what comes next.", in: CGRect(x: 890, y: 306, width: 250, height: 96), size: 24, weight: .medium, color: ink.withAlphaComponent(0.76))
  }
}

let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
var frameIndex = 0

while frameIndex < totalFrames {
  while !input.isReadyForMoreMediaData {
    Thread.sleep(forTimeInterval: 0.01)
  }

  var pixelBuffer: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
  guard let buffer = pixelBuffer else { fatalError("Could not create pixel buffer") }

  CVPixelBufferLockBaseAddress(buffer, [])
  let context = CGContext(
    data: CVPixelBufferGetBaseAddress(buffer),
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
  )!
  context.clear(CGRect(x: 0, y: 0, width: width, height: height))
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  drawFrame(frameIndex, in: context)
  NSGraphicsContext.restoreGraphicsState()
  CVPixelBufferUnlockBaseAddress(buffer, [])

  let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
  adaptor.append(buffer, withPresentationTime: presentationTime)
  frameIndex += 1
}

input.markAsFinished()
writer.finishWriting {
  if writer.status == .completed {
    print("Wrote \(outputPath)")
  } else {
    fatalError("Writer failed: \(writer.error?.localizedDescription ?? "unknown")")
  }
}

while writer.status == .writing {
  RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}