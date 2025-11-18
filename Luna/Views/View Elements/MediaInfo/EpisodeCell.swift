//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct EpisodeCell: View {
    
    @Environment(\.colorScheme) private var colorScheme
    let episode: TMDBEpisode
    let showId: Int
    let progress: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onResetProgress: () -> Void
    
    let fillerEpisodes: Set<Int>?
    @State private var isFiller: Bool = false
    @State private var isWatched: Bool = false
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false
    
    private var episodeKey: String {
        "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
    }
    
    var body: some View {
        if horizontalEpisodeList {
            horizontalLayout
        } else {
            verticalLayout
        }
    }
    
    @MainActor private var horizontalLayout: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 240, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if progress > 0 && progress < 0.95 {
                        VStack {
                            Spacer()
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .frame(height: 3)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                        }
                        .frame(width: 240, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 2) {
                                if episode.voteAverage > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", episode.voteAverage))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .applyLiquidGlassBackground(
                            cornerRadius: 16,
                            fallbackFill: Color.gray.opacity(0.2),
                            fallbackMaterial: .thinMaterial,
                            glassTint: Color.gray.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    
                    if isFiller {
                        Text("Filler")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(colorScheme == .dark ? 0.20 : 0.10))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.24), lineWidth: 0.6)
                            )
                            .foregroundColor(.red)
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(12)
            .applyLiquidGlassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            let epNum = episode.episodeNumber
            if let set = fillerEpisodes { self.isFiller = set.contains(epNum) } else { self.isFiller = false }
            loadEpisodeProgress()
        }
    }
    
    @MainActor private var verticalLayout: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    if progress > 0 && progress < 0.95 {
                        VStack {
                            Spacer()
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                .frame(height: 3)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                        }
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 2) {
                                if episode.voteAverage > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", episode.voteAverage))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .applyLiquidGlassBackground(
                            cornerRadius: 16,
                            fallbackFill: Color.gray.opacity(0.2),
                            fallbackMaterial: .thinMaterial,
                            glassTint: Color.gray.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    
                    if isFiller {
                        Text("Filler")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(colorScheme == .dark ? 0.20 : 0.10))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.24), lineWidth: 0.6)
                            )
                            .foregroundColor(.red)
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .applyLiquidGlassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            let epNum = episode.episodeNumber
            if let set = fillerEpisodes { self.isFiller = set.contains(epNum) } else { self.isFiller = false }
            loadEpisodeProgress()
        }
    }
    
    @ViewBuilder
    private var episodeContextMenu: some View {
        Button(action: {
            onTap()
        }) {
            Label("Play Episode", systemImage: "play.circle.fill")
        }
        
        if !isWatched {
            Button(action: {
                onMarkWatched()
                isWatched = true
            }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
        } else {
            Button(action: {
                onResetProgress()
                isWatched = false
            }) {
                Label("Mark as Unwatched", systemImage: "xmark.circle")
            }
        }
        
        if progress > 0 {
            Button(role: .destructive, action: {
                ProgressManager.shared.resetEpisodeProgress(
                    showId: showId,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber
                )
                onResetProgress()
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
        }
    }
    
    private func loadEpisodeProgress() {
        isWatched = ProgressManager.shared.isEpisodeWatched(
            showId: showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
}