//
//  SidebarView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct SidebarView: View {
    @ObservedObject var library: GameLibrary
    @ObservedObject var settings: ArcadeSettings
    
    public var body: some View {
        List {
            Section(header: Text("ARCADE LIBRARY").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))) {
                ForEach(SidebarFilter.allCases) { filter in
                    Button(action: {
                        library.selectedFilter = filter
                        library.selectedCategory = .all
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: filter.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(iconColor(for: filter))
                                .frame(width: 20)
                            
                            Text(filter.title)
                                .font(.system(size: 13, weight: library.selectedFilter == filter ? .semibold : .regular))
                            
                            Spacer()
                            
                            Text("\(count(for: filter))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(library.selectedFilter == filter ? Color.white.opacity(0.2) : Color.gray.opacity(0.15)))
                                .foregroundColor(library.selectedFilter == filter ? .white : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        library.selectedFilter == filter ?
                            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.25)) :
                            RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                    )
                }
            }
            
            Section(header: Text("GENRES & CATEGORIES").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(red: 1.0, green: 0.1, blue: 0.6))) {
                ForEach(GameCategory.allCases.filter { $0 != .all }) { category in
                    Button(action: {
                        library.selectedCategory = (library.selectedCategory == category) ? .all : category
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 13))
                                .foregroundColor(library.selectedCategory == category ? Color(red: 1.0, green: 0.1, blue: 0.6) : .secondary)
                                .frame(width: 20)
                            
                            Text(category.displayName)
                                .font(.system(size: 12, weight: library.selectedCategory == category ? .semibold : .regular))
                            
                            Spacer()
                            
                            let catCount = library.games.filter { $0.category == category }.count
                            if catCount > 0 {
                                Text("\(catCount)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        library.selectedCategory == category ?
                            RoundedRectangle(cornerRadius: 6).fill(Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.2)) :
                            RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                    )
                }
            }
            
            Section(header: Text("ARCADE STATS").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Games", systemImage: "gamecontroller")
                        Spacer()
                        Text("\(library.totalGamesCount)")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 12))
                    
                    HStack {
                        Label("Total Plays", systemImage: "play.circle")
                        Spacer()
                        Text("\(library.totalPlayCount)")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 12))
                    
                    HStack {
                        Label("Playtime", systemImage: "timer")
                        Spacer()
                        Text(formattedTotalTime)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Divider()
                Button(action: {
                    library.isAddGameSheetPresented = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("ADD GAME")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.5)
                    }
                    .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
    
    private func count(for filter: SidebarFilter) -> Int {
        switch filter {
        case .all: return library.totalGamesCount
        case .flash: return library.flashGamesCount
        case .html5: return library.htmlGamesCount
        case .favorites: return library.favoritesCount
        case .recent: return library.games.filter { $0.lastPlayed != nil }.count
        }
    }
    
    private func iconColor(for filter: SidebarFilter) -> Color {
        switch filter {
        case .all: return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .flash: return Color(red: 1.0, green: 0.4, blue: 0.1)
        case .html5: return Color(red: 0.0, green: 0.85, blue: 0.95)
        case .favorites: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .recent: return Color(red: 0.5, green: 0.5, blue: 1.0)
        }
    }
    
    private var formattedTotalTime: String {
        let seconds = library.totalPlayDuration
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            let h = Int(seconds / 3600)
            let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h \(m)m"
        }
    }
}
