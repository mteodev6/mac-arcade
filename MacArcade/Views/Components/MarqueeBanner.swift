//
//  MarqueeBanner.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct MarqueeBanner: View {
    public let title: String
    public var accentColor: Color = Color(red: 0.0, green: 0.95, blue: 1.0)
    
    @State private var isPulsing = false
    
    public var body: some View {
        HStack(spacing: 12) {
            // Left decorative coin slot / bulb
            Circle()
                .fill(Color(red: 1.0, green: 0.1, blue: 0.5))
                .frame(width: 8, height: 8)
                .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.5), radius: 6)
            
            Text(title.uppercased())
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .tracking(4)
                .foregroundColor(.white)
                .shadow(color: accentColor.opacity(isPulsing ? 1.0 : 0.6), radius: isPulsing ? 12 : 6)
            
            // Right decorative coin slot / bulb
            Circle()
                .fill(Color(red: 0.0, green: 1.0, blue: 0.8))
                .frame(width: 8, height: 8)
                .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.8), radius: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.12))
                
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accentColor.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
