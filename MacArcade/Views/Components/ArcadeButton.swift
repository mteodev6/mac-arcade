//
//  ArcadeButton.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct ArcadeButton: View {
    public let title: String
    public let systemImage: String?
    public var color: Color = Color(red: 0.0, green: 0.95, blue: 1.0)
    public let action: () -> Void
    
    @State private var isHovered = false
    
    public init(_ title: String, systemImage: String? = nil, color: Color = Color(red: 0.0, green: 0.95, blue: 1.0), action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundColor(isHovered ? .black : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? color : color.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color, lineWidth: 1.5)
                }
            )
            .shadow(color: color.opacity(isHovered ? 0.8 : 0.3), radius: isHovered ? 10 : 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
