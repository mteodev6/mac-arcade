//
//  CRTShaderOverlay.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct CRTShaderOverlay: View {
    public var opacity: Double = 0.65
    public var showGlow: Bool = true
    
    @State private var scanlineOffset: CGFloat = 0
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Subtle horizontal scanlines
                Canvas { context, size in
                    let step: CGFloat = 3.5
                    var y: CGFloat = 0
                    while y < size.height {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: 1.2)
                        context.fill(Path(rect), with: .color(Color.black.opacity(opacity * 0.45)))
                        y += step
                    }
                }
                
                // 2. Vintage Vignette (darkened corners of CRT tube)
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.65)
                    ]),
                    center: .center,
                    startRadius: min(geometry.size.width, geometry.size.height) * 0.35,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.75
                )
                
                // 3. Phosphor RGB subtle vertical lines
                Canvas { context, size in
                    let step: CGFloat = 6.0
                    var x: CGFloat = 0
                    while x < size.width {
                        let rect = CGRect(x: x, y: 0, width: 1.0, height: size.height)
                        context.fill(Path(rect), with: .color(Color(red: 0.0, green: 1.0, blue: 0.8).opacity(0.015)))
                        x += step
                    }
                }
                
                // 4. Glass reflection glare top-left
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .allowsHitTesting(false)
    }
}
