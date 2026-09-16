//
//  DropZoneOverlay.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct DropZoneOverlay: View {
    public let isTargeted: Bool
    
    public var body: some View {
        if isTargeted {
            ZStack {
                Color.black.opacity(0.85)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                        .shadow(color: Color(red: 0.0, green: 0.95, blue: 1.0), radius: 20)
                    
                    Text("DROP TO ADD TO ARCADE")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.white)
                        .shadow(color: Color(red: 0.0, green: 0.95, blue: 1.0), radius: 10)
                    
                    Text("Accepts .SWF Flash games, .HTML5 files, or .ZIP game packages")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.08, green: 0.1, blue: 0.18).opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.1, blue: 0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, dash: [10, 8])
                                )
                        )
                )
            }
            .transition(.opacity)
        }
    }
}
