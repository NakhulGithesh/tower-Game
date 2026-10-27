import Foundation
import CoreGraphics
import ImageIO

func createCastleAttackAppIcon(outputPath: String) {
    let size = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        print("Failed to create CGContext")
        exit(1)
    }
    
    // Flip coordinate system so (0,0) is top-left
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1.0, y: -1.0)
    
    // 1. Deep Midnight & Purple Twilight Gradient Background
    let bgColors = [
        CGColor(red: 0.12, green: 0.05, blue: 0.22, alpha: 1.0), // Deep purple night
        CGColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1.0)  // Midnight navy
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 512, y: 0),
        end: CGPoint(x: 512, y: 1024),
        options: []
    )
    
    // 2. Radial Elixir Flame Glow in Background
    let elixirGlowColors = [
        CGColor(red: 0.75, green: 0.15, blue: 0.95, alpha: 0.55),
        CGColor(red: 0.40, green: 0.10, blue: 0.70, alpha: 0.20),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    let elixirGradient = CGGradient(colorsSpace: colorSpace, colors: elixirGlowColors, locations: [0.0, 0.45, 1.0])!
    context.drawRadialGradient(
        elixirGradient,
        startCenter: CGPoint(x: 512, y: 560),
        startRadius: 40,
        endCenter: CGPoint(x: 512, y: 560),
        endRadius: 460,
        options: []
    )
    
    // 3. Stone Castle Tower Silhouette
    let stoneDark = CGColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1.0)
    let stoneMid = CGColor(red: 0.26, green: 0.28, blue: 0.36, alpha: 1.0)
    let stoneLight = CGColor(red: 0.38, green: 0.42, blue: 0.50, alpha: 1.0)
    let goldColor = CGColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 1.0)
    let royalBlue = CGColor(red: 0.12, green: 0.48, blue: 0.95, alpha: 1.0)
    
    // Tower Foundation
    context.setFillColor(stoneDark)
    context.setStrokeColor(stoneLight)
    context.setLineWidth(6.0)
    context.fill(CGRect(x: 290, y: 720, width: 444, height: 160))
    context.stroke(CGRect(x: 290, y: 720, width: 444, height: 160))
    
    // Main Tower Shaft (Tapered)
    let shaftPath = CGMutablePath()
    shaftPath.move(to: CGPoint(x: 320, y: 720))
    shaftPath.addLine(to: CGPoint(x: 350, y: 320))
    shaftPath.addLine(to: CGPoint(x: 674, y: 320))
    shaftPath.addLine(to: CGPoint(x: 704, y: 720))
    shaftPath.closeSubpath()
    
    context.setFillColor(stoneMid)
    context.addPath(shaftPath)
    context.fillPath()
    
    context.setStrokeColor(stoneDark)
    context.setLineWidth(8.0)
    context.addPath(shaftPath)
    context.strokePath()
    
    // Mortar / Brick Lines on Tower
    context.setStrokeColor(stoneDark)
    context.setLineWidth(4.0)
    for y in [420, 500, 580, 660] {
        context.move(to: CGPoint(x: 345, y: CGFloat(y)))
        context.addLine(to: CGPoint(x: 679, y: CGFloat(y)))
        context.strokePath()
    }
    
    // Battlements Parapets (Top of Tower)
    let battlementPath = CGMutablePath()
    let bY: CGFloat = 320
    battlementPath.move(to: CGPoint(x: 320, y: bY))
    battlementPath.addLine(to: CGPoint(x: 320, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 390, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 390, y: bY - 45))
    battlementPath.addLine(to: CGPoint(x: 470, y: bY - 45))
    battlementPath.addLine(to: CGPoint(x: 470, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 554, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 554, y: bY - 45))
    battlementPath.addLine(to: CGPoint(x: 634, y: bY - 45))
    battlementPath.addLine(to: CGPoint(x: 634, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 704, y: bY - 110))
    battlementPath.addLine(to: CGPoint(x: 704, y: bY))
    battlementPath.closeSubpath()
    
    context.setFillColor(stoneLight)
    context.addPath(battlementPath)
    context.fillPath()
    
    context.setStrokeColor(stoneDark)
    context.setLineWidth(8.0)
    context.addPath(battlementPath)
    context.strokePath()
    
    // 4. Crossed Golden Swords Behind Shield
    func drawSword(angle: CGFloat) {
        context.saveGState()
        context.translateBy(x: 512, y: 510)
        context.rotate(by: angle)
        
        // Blade
        context.setFillColor(CGColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1.0))
        let bladePath = CGMutablePath()
        bladePath.move(to: CGPoint(x: 0, y: -260))
        bladePath.addLine(to: CGPoint(x: 22, y: -210))
        bladePath.addLine(to: CGPoint(x: 18, y: 140))
        bladePath.addLine(to: CGPoint(x: -18, y: 140))
        bladePath.addLine(to: CGPoint(x: -22, y: -210))
        bladePath.closeSubpath()
        context.addPath(bladePath)
        context.fillPath()
        
        // Crossguard
        context.setFillColor(goldColor)
        context.fill(CGRect(x: -60, y: 135, width: 120, height: 26))
        
        // Grip & Pommel
        context.setFillColor(CGColor(red: 0.50, green: 0.25, blue: 0.12, alpha: 1.0))
        context.fill(CGRect(x: -10, y: 161, width: 20, height: 70))
        context.setFillColor(goldColor)
        context.fillEllipse(in: CGRect(x: -20, y: 225, width: 40, height: 40))
        
        context.restoreGState()
    }
    
    drawSword(angle: .pi / 4.2)
    drawSword(angle: -.pi / 4.2)
    
    // 5. Stylized Royal Blue Shield Crest (Centerpiece)
    let shieldPath = CGMutablePath()
    shieldPath.move(to: CGPoint(x: 350, y: 390))
    shieldPath.addLine(to: CGPoint(x: 674, y: 390))
    shieldPath.addLine(to: CGPoint(x: 674, y: 550))
    shieldPath.addQuadCurve(to: CGPoint(x: 512, y: 700), control: CGPoint(x: 674, y: 660))
    shieldPath.addQuadCurve(to: CGPoint(x: 350, y: 550), control: CGPoint(x: 350, y: 660))
    shieldPath.closeSubpath()
    
    // Shield Drop Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
    context.setFillColor(royalBlue)
    context.addPath(shieldPath)
    context.fillPath()
    context.restoreGState()
    
    // Inner Blue Gradient
    let shieldColors = [
        CGColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.08, green: 0.35, blue: 0.85, alpha: 1.0)
    ] as CFArray
    let shieldGradient = CGGradient(colorsSpace: colorSpace, colors: shieldColors, locations: [0.0, 1.0])!
    context.saveGState()
    context.addPath(shieldPath)
    context.clip()
    context.drawLinearGradient(shieldGradient, start: CGPoint(x: 512, y: 390), end: CGPoint(x: 512, y: 700), options: [])
    context.restoreGState()
    
    // Gold Beveled Shield Border
    context.setStrokeColor(goldColor)
    context.setLineWidth(16.0)
    context.addPath(shieldPath)
    context.strokePath()
    
    // 6. Golden Crown on Shield
    context.setFillColor(goldColor)
    let crownPath = CGMutablePath()
    let cX: CGFloat = 512
    let cY: CGFloat = 520
    crownPath.move(to: CGPoint(x: cX - 60, y: cY + 30))
    crownPath.addLine(to: CGPoint(x: cX - 70, y: cY - 35))
    crownPath.addLine(to: CGPoint(x: cX - 30, y: cY - 10))
    crownPath.addLine(to: CGPoint(x: cX, y: cY - 45))
    crownPath.addLine(to: CGPoint(x: cX + 30, y: cY - 10))
    crownPath.addLine(to: CGPoint(x: cX + 70, y: cY - 35))
    crownPath.addLine(to: CGPoint(x: cX + 60, y: cY + 30))
    crownPath.closeSubpath()
    
    context.addPath(crownPath)
    context.fillPath()
    
    // Crown Jewels (Emerald & Ruby)
    context.setFillColor(CGColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: cX - 8, y: cY + 5, width: 16, height: 16))
    context.setFillColor(CGColor(red: 0.15, green: 0.90, blue: 0.35, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: cX - 42, y: cY + 5, width: 14, height: 14))
    context.fillEllipse(in: CGRect(x: cX + 28, y: cY + 5, width: 14, height: 14))
    
    // 7. Outer Royal Beveled Gold Border on App Icon
    let outerRect = CGRect(x: 28, y: 28, width: 968, height: 968)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: 210, cornerHeight: 210, transform: nil)
    context.setStrokeColor(CGColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 0.45))
    context.setLineWidth(14.0)
    context.addPath(outerPath)
    context.strokePath()
    
    // Save to PNG file
    guard let image = context.makeImage() else {
        print("Failed to make CGImage")
        exit(1)
    }
    
    let url = URL(fileURLWithPath: outputPath)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("Failed to create CGImageDestination")
        exit(1)
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    if CGImageDestinationFinalize(destination) {
        print("✅ Successfully generated 1024x1024 Castle Attack App Icon at \(outputPath)")
    } else {
        print("❌ Failed to save PNG file")
        exit(1)
    }
}

let target = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "CastleAttack/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"

createCastleAttackAppIcon(outputPath: target)
