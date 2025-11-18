//
//  FillerHelpers.swift
//  Luna
//
//  Created by scigward on 11/18/25
//

import Foundation
import Combine

// MARK: - AniList

struct AniListTitle: Codable {
    let romaji: String?
    let english: String?
    let native: String?
}

struct AniListStartDate: Codable {
    let year: Int?
}

enum AniListFormat: String, Codable {
    case TV, TV_SHORT, ONA, OVA, MOVIE, SPECIAL, UNKNOWN
}

struct AniListMedia: Codable {
    let id: Int
    let idMal: Int?
    let title: AniListTitle
    let startDate: AniListStartDate?
    let format: AniListFormat?
}

private struct AniListPage: Codable {
    let media: [AniListMedia]
}

private struct AniListResponse: Codable {
    struct Container: Codable { let Page: AniListPage }
    let data: Container
}

final class AniListClient {
    static let shared = AniListClient()
    private init() {}

    private let endpoint = URL(string: "https://graphql.anilist.co")!

    func searchAnime(title: String, startYear: Int?) async throws -> [AniListMedia] {
        let query = """
        query($search: String, $year: Int) {
          Page(perPage: 10) {
            media(search: $search, type: ANIME) {
              id
              idMal
              title { romaji english native }
              startDate { year }
              format
            }
          }
        }
        """
        var variables: [String: Any] = ["search": title]
        if let y = startYear { variables["year"] = y }
        let body: [String: Any] = ["query": query, "variables": variables]
        let payload = try JSONSerialization.data(withJSONObject: body, options: [])

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload

        Logger.shared.log("AniList: search '\(title)' year=\(startYear.map(String.init) ?? "nil")", type: "Debug")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "AniListClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AniList HTTP \(http.statusCode)"])
        }
        let decoded = try JSONDecoder().decode(AniListResponse.self, from: data)
        return decoded.data.Page.media
    }
}

// MARK: - Jikan

struct JikanEpisode: Codable {
    let mal_id: Int 
    let filler: Bool?
}

private struct JikanEpisodesPage: Codable {
    struct Pagination: Codable { let has_next_page: Bool }
    let data: [JikanEpisode]
    let pagination: Pagination
}

final class JikanClient {
    static let shared = JikanClient()
    private init() {}

    private let base = URL(string: "https://api.jikan.moe/v4")!

    func fetchFillerEpisodeNumbers(malAnimeId: Int) async throws -> Set<Int> {
        var page = 1
        var filler = Set<Int>()
        var attempts = 0

        while true {
            var comps = URLComponents(url: base.appendingPathComponent("/anime/\(malAnimeId)/episodes"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "100")
            ]
            guard let url = comps.url else { break }

            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                    let delay = min(pow(1.5, Double(attempts)), 5.0)
                    attempts += 1
                    Logger.shared.log("Jikan 429, backoff \(String(format: "%.2f", delay))s (page \(page))", type: "Debug")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                let decoded = try JSONDecoder().decode(JikanEpisodesPage.self, from: data)
                for (index, ep) in decoded.data.enumerated() where ep.filler == true {
                    let episodeNumber = (page - 1) * 100 + index + 1
                    filler.insert(episodeNumber)
                }
                if decoded.pagination.has_next_page {
                    page += 1
                    continue
                } else {
                    break
                }
            } catch {
                if attempts < 5 {
                    let delay = min(pow(1.5, Double(attempts)), 5.0)
                    attempts += 1
                    Logger.shared.log("Jikan error: \(error.localizedDescription). Retry in \(String(format: "%.2f", delay))s", type: "Error")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    throw error
                }
            }
        }
        return filler
    }
}

// MARK: - Persistent Cache (12 hours)

private struct FillerCacheEntry: Codable {
    let fetchedAt: Date
    let fillerEpisodes: [Int]
}

private struct FillerCacheDiskModel: Codable {
    var byTMDB: [Int: FillerCacheEntry]
}

// MARK: - AnilistMapper

@MainActor
final class AnilistMapper: ObservableObject {
    static let shared = AnilistMapper()

    @Published private(set) var fillerSetsByTMDB: [Int: Set<Int>] = [:]

    // Memory + Disk cache
    private var memoryCache: [Int: (fetchedAt: Date, filler: Set<Int>)] = [:]
    private let ttl: TimeInterval = 60 * 60 * 12  // 12 hours
    private var inFlight: Set<Int> = []
    private let cacheURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = caches.appendingPathComponent("anilist_filler_cache.json")
        self.loadCacheFromDisk()
    }

    func fillerSet(for tmdbShowId: Int) -> Set<Int>? {
        if let entry = memoryCache[tmdbShowId], Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.filler
        }
        // Disk fallback
        if let disk = try? Data(contentsOf: cacheURL),
           let model = try? JSONDecoder().decode(FillerCacheDiskModel.self, from: disk),
           let entry = model.byTMDB[tmdbShowId],
           Date().timeIntervalSince(entry.fetchedAt) < ttl {
            let set = Set(entry.fillerEpisodes)
            memoryCache[tmdbShowId] = (entry.fetchedAt, set)
            fillerSetsByTMDB[tmdbShowId] = set
            return set
        }
        return nil
    }

    func loadIfNeeded(tmdbShowId: Int, tmdbService: TMDBService) async {
        // Feature flag (default true)
        let enabled = (UserDefaults.standard.object(forKey: "enableFillerBadges") as? Bool) ?? true
        if !enabled {
            Logger.shared.log("Filler disabled via flag", type: "Debug")
            return
        }
        // Cache hit
        if let cached = fillerSet(for: tmdbShowId) {
            Logger.shared.log("Filler cache hit for TMDB \(tmdbShowId)", type: "Debug")
            fillerSetsByTMDB[tmdbShowId] = cached
            return
        }
        if inFlight.contains(tmdbShowId) { return }
        inFlight.insert(tmdbShowId)
        defer { inFlight.remove(tmdbShowId) }

        do {
            let show = try await tmdbService.getTVShowWithSeasons(id: tmdbShowId)
            let title = show.name
            let altTitle = show.originalName ?? show.name
            let startYear = show.firstAirDate.flatMap { $0.prefix(4) }.flatMap { Int($0) }
            Logger.shared.log("Map TMDB \(tmdbShowId) '\(title)' year=\(startYear.map(String.init) ?? "nil") → AniList", type: "Debug")

            let candidates = try await AniListClient.shared.searchAnime(title: title, startYear: startYear)
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedAlt = altTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let exact = candidates.first(where: { m in
                let anyTitle = [m.title.english, m.title.romaji, m.title.native]
                    .compactMap { $0?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                let titleMatch = anyTitle.contains(normalizedTitle) || anyTitle.contains(normalizedAlt)
                let yearMatch = (m.startDate?.year ?? -1) == (startYear ?? -2)
                return titleMatch && yearMatch
            })

            guard let match = exact, let malId = match.idMal else {
                Logger.shared.log("AniList strict match failed for TMDB \(tmdbShowId) → no-op", type: "Debug")
                return
            }
            Logger.shared.log("Matched AniList \(match.id) with MAL \(malId) for TMDB \(tmdbShowId)", type: "Success")

            let set = try await JikanClient.shared.fetchFillerEpisodeNumbers(malAnimeId: malId)
            Logger.shared.log("Fetched \(set.count) filler eps for MAL \(malId)", type: "Success")

            memoryCache[tmdbShowId] = (Date(), set)
            fillerSetsByTMDB[tmdbShowId] = set
            saveCacheToDisk()
        } catch {
            Logger.shared.log("Filler load error (TMDB \(tmdbShowId)): \(error.localizedDescription)", type: "Error")
        }
    }

    // MARK: - Disk Cache Helpers

    private func loadCacheFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let model = try? JSONDecoder().decode(FillerCacheDiskModel.self, from: data) {
            var mem: [Int: (Date, Set<Int>)] = [:]
            for (k, v) in model.byTMDB {
                mem[k] = (v.fetchedAt, Set(v.fillerEpisodes))
            }
            self.memoryCache = mem
        }
    }

    private func saveCacheToDisk() {
        var dict: [Int: FillerCacheEntry] = [:]
        for (k, v) in memoryCache {
            dict[k] = FillerCacheEntry(fetchedAt: v.fetchedAt, fillerEpisodes: Array(v.filler))
        }
        let model = FillerCacheDiskModel(byTMDB: dict)
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: cacheURL, options: [.atomic])
        }
    }
}