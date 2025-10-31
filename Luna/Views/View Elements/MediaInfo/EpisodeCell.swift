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
    let fillerEpisodes: Set<Int>? 
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onResetProgress: () -> Void
    
    @State private var isWatched: Bool = false
    @State private var isFiller: Bool = false
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false
    
    private var episodeKey: String {
    "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
    }
    
    private var isFillerComputed: Bool {
        return fillerEpisodes?.contains(episode.episodeNumber) ?? false
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

if isFillerComputed {
    Text("Filler")
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.red.opacity(colorScheme == .dark ? 0.20 : 0.10)))
        .overlay(Capsule().stroke(Color.red.opacity(0.24), lineWidth: 0.6))
        .foregroundColor(.red)
}
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 2) {
                                if episode.voteAverage > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", episode.voteAverage))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(.secondary)
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
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
                .frame(width: 240, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
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
                                        .foregroundColor(.secondary)
                                    
                                    
                                    Text(" - ")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let runtime = episode.runtime, runtime > 0 {
                                    Text(episode.runtimeFormatted)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(.secondary)
                    }
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            )
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
            loadEpisodeProgress()
        }
    }
    
    private var episodeContextMenu: some View {
        Group {
            Button(action: onTap) {
                Label("Play", systemImage: "play.fill")
            }
            
            if progress < 0.95 {
                Button(action: {
                    ProgressManager.shared.markEpisodeAsWatched(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onMarkWatched()
                    isWatched = true
                }) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress > 0 {
                Button(action: {
                    ProgressManager.shared.resetEpisodeProgress(
                        showId: showId,
                        seasonNumber: episode.seasonNumber,
                        episodeNumber: episode.episodeNumber
                    )
                    onResetProgress()
                    isWatched = false
                }) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    private func loadEpisodeProgress() {
        if let set = fillerEpisodes { self.isFiller = set.contains(episode.episodeNumber); if self.isFiller { Logger.shared.log("[Filler] Episode #\(episode.episodeNumber) marked as filler", type: "Debug") } }
        isWatched = ProgressManager.shared.isEpisodeWatched(
            showId: showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
}