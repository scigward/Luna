//
//  ShowsDetails.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct TVShowSeasonsSection: View {
    let tvShow: TMDBTVShowWithSeasons?
    @Binding var selectedSeason: TMDBSeason?
    @Binding var seasonDetail: TMDBSeasonDetail?
    @Binding var selectedEpisodeForSearch: TMDBEpisode?
    let tmdbService: TMDBService

    // Jikan filler set for this media (passed down to EpisodeCell)
    @State private var jikanFillerSet: Set<Int>? = nil

    private static var jikanCache: [Int: (fetchedAt: Date, episodes: [JikanEpisode])] = [:]
    private static let jikanCacheQueue = DispatchQueue(label: "sora.jikan.cache.queue", attributes: .concurrent)
    private static let jikanCacheTTL: TimeInterval = 60 * 60 * 24 * 7 // 1 week
    private static var inProgressMALIDs: Set<Int> = []
    private static let inProgressQueue = DispatchQueue(label: "sora.jikan.inprogress.queue")

    @State private var matchedMalID: Int? = nil

    
    @State private var isLoadingSeason = false
    @State private var showingSearchResults = false
    @State private var showingNoServicesAlert = false
    @State private var romajiTitle: String?
    
    @StateObject private var serviceManager = ServiceManager.shared
    @AppStorage("horizontalEpisodeList") private var horizontalEpisodeList: Bool = false
    
    private var isGroupedBySeasons: Bool {
        return tvShow?.seasons.filter { $0.seasonNumber > 0 }.count ?? 0 > 1
    }
    
    private var useSeasonMenu: Bool {
        return UserDefaults.standard.bool(forKey: "seasonMenu")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tvShow = tvShow {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    if let numberOfSeasons = tvShow.numberOfSeasons, numberOfSeasons > 0 {
                        DetailRow(title: "Seasons", value: "\(numberOfSeasons)")
                    }
                    
                    if let numberOfEpisodes = tvShow.numberOfEpisodes, numberOfEpisodes > 0 {
                        DetailRow(title: "Episodes", value: "\(numberOfEpisodes)")
                    }
                    
                    if !tvShow.genres.isEmpty {
                        DetailRow(title: "Genres", value: tvShow.genres.map { $0.name }.joined(separator: ", "))
                    }
                    
                    if tvShow.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", tvShow.voteAverage))
                    }
                    
                    if let ageRating = getAgeRating(from: tvShow.contentRatings) {
                        DetailRow(title: "Age Rating", value: ageRating)
                    }
                    
                    if let firstAirDate = tvShow.firstAirDate, !firstAirDate.isEmpty {
                        DetailRow(title: "First aired", value: "\(firstAirDate)")
                    }
                    
                    if let lastAirDate = tvShow.lastAirDate, !lastAirDate.isEmpty {
                        DetailRow(title: "Last aired", value: "\(lastAirDate)")
                    }
                    
                    if let status = tvShow.status {
                        DetailRow(title: "Status", value: status)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                )
                .padding(.horizontal)
                
                if !tvShow.seasons.isEmpty {
                    if isGroupedBySeasons && !useSeasonMenu {
                        HStack {
                            Text("Seasons")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        seasonSelectorStyled
                        
                        HStack {
                            Text("Episodes")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    } else {
                        episodesSectionHeader
                    }
                    
                    episodeListSection
                }
            }
        }
        .onAppear {
            if let tvShow = tvShow, let selectedSeason = selectedSeason {
                loadSeasonDetails(tvShowId: tvShow.id, season: selectedSeason)
                Task {
                    let romaji = await tmdbService.getRomajiTitle(for: "tv", id: tvShow.id)
                    await MainActor.run {
                        self.romajiTitle = romaji
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: tvShow?.name ?? "Unknown Show",
                originalTitle: romajiTitle,
                isMovie: false,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: tvShow?.id ?? 0
            )
        }
        .alert("No Active Services", isPresented: $showingNoServicesAlert) {
            Button("OK") { }
        } message: {
            Text("You don't have any active services. Please go to the Services tab to download and activate services.")
        }
    }
    
    @ViewBuilder
    private var episodesSectionHeader: some View {
        HStack {
            Text("Episodes")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            if let tvShow = tvShow, isGroupedBySeasons && useSeasonMenu {
                seasonMenu(for: tvShow)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    @ViewBuilder
    private func seasonMenu(for tvShow: TMDBTVShowWithSeasons) -> some View {
        let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
        
        if seasons.count > 1 {
            Menu {
                ForEach(seasons) { season in
                    Button(action: {
                        selectedSeason = season
                        loadSeasonDetails(tvShowId: tvShow.id, season: season)
                    }) {
                        HStack {
                            Text(season.name)
                            if selectedSeason?.id == season.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedSeason?.name ?? "Season 1")
                    
                    Image(systemName: "chevron.down")
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var seasonSelectorStyled: some View {
        if let tvShow = tvShow {
            let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
            if seasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(seasons) { season in
                            Button(action: {
                                selectedSeason = season
                                loadSeasonDetails(tvShowId: tvShow.id, season: season)
                            }) {
                                VStack(spacing: 8) {
                                    KFImage(URL(string: season.fullPosterURL ?? ""))
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 80, height: 120)
                                                .overlay(
                                                    VStack {
                                                        Image(systemName: "tv")
                                                            .font(.title2)
                                                            .foregroundColor(.white.opacity(0.7))
                                                        Text("S\(season.seasonNumber)")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                )
                                        }
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedSeason?.id == season.id ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                    
                                    Text(season.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 80)
                                        .foregroundColor(selectedSeason?.id == season.id ? .accentColor : .primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodeListSection: some View {
        Group {
            if let seasonDetail = seasonDetail {
                if horizontalEpisodeList {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 15) {
                            ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                                createEpisodeCell(episode: episode, index: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                            createEpisodeCell(episode: episode, index: index)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if isLoadingSeason {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading episodes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    @ViewBuilder
    private func createEpisodeCell(episode: TMDBEpisode, index: Int) -> some View {
        if let tvShow = tvShow {
            let progress = ProgressManager.shared.getEpisodeProgress(
                showId: tvShow.id,
                seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber
            )
            let isSelected = selectedEpisodeForSearch?.id == episode.id
            
            EpisodeCell(
                episode: episode,
                fillerEpisodes: jikanFillerSet,
                showId: tvShow.id,
                progress: progress,
                isSelected: isSelected,
                onTap: { episodeTapAction(episode: episode) },
                onMarkWatched: { markAsWatched(episode: episode) },
                onResetProgress: { resetProgress(episode: episode) }
            )
        } else {
            EmptyView()
        }
    }
    
    private func episodeTapAction(episode: TMDBEpisode) {
        selectedEpisodeForSearch = episode
        searchInServicesForEpisode(episode: episode)
    }
    
    private func searchInServicesForEpisode(episode: TMDBEpisode) {
        guard (tvShow?.name) != nil else { return }
        
        if serviceManager.activeServices.isEmpty {
            showingNoServicesAlert = true
            return
        }
        
        showingSearchResults = true
    }
    
    private func markAsWatched(episode: TMDBEpisode) {
        guard let tvShow = tvShow else { return }
        ProgressManager.shared.markEpisodeAsWatched(
            showId: tvShow.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
    
    private func resetProgress(episode: TMDBEpisode) {
        guard let tvShow = tvShow else { return }
        ProgressManager.shared.resetEpisodeProgress(
            showId: tvShow.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber
        )
    }
    
    private func loadSeasonDetails(tvShowId: Int, season: TMDBSeason) {
        isLoadingSeason = true
        
        Task {
            do {
                let detail = try await tmdbService.getSeasonDetails(tvShowId: tvShowId, seasonNumber: season.seasonNumber)
                await MainActor.run {
                    self.seasonDetail = detail
                    self.isLoadingSeason = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSeason = false
                }
            }
        }
    }
    
    private func getAgeRating(from contentRatings: TMDBContentRatings?) -> String? {
        guard let contentRatings = contentRatings else { return nil }
        
        for rating in contentRatings.results {
            if rating.iso31661 == "US" && !rating.rating.isEmpty {
                return rating.rating
            }
        }
        
        for rating in contentRatings.results {
            if !rating.rating.isEmpty {
                return rating.rating
            }
        }
        
        return nil
    }

    private struct JikanResponse: Decodable {
        let data: [JikanEpisode]
    }
    
    private struct JikanEpisode: Decodable {
        let mal_id: Int
        let filler: Bool
    }

    private func fetchJikanFillerInfoIfNeeded() {
        Logger.shared.log("[Filler] fetchJikanFillerInfoIfNeeded invoked", type: "Debug")
        guard jikanFillerSet == nil else { return }
        fetchJikanFillerInfo()
    }

    private func fetchJikanFillerInfo() {
        Logger.shared.log("[Filler] fetchJikanFillerInfo start", type: "Debug")
        guard let malID = matchedMalID else {
            Logger.shared.log("[Filler] MAL ID missing — resolving via AniList", type: "Debug")
            // Resolve via AniList using TMDB title/year
            resolveMalIDFromTMDBForAniList()
            return
        }

        // Check cache first
        var cachedEpisodes: [JikanEpisode]? = nil
        Self.jikanCacheQueue.sync {
            if let entry = Self.jikanCache[malID], Date().timeIntervalSince(entry.fetchedAt) < Self.jikanCacheTTL {
                cachedEpisodes = entry.episodes
            }
        }
        if let episodes = cachedEpisodes {
            Logger.shared.log("[Filler] Cache hit for MAL ID: \(malID) episodes=\(episodes.count)", type: "Debug")
            updateFillerSet(episodes: episodes)
            return
        }
        
        Logger.shared.log("[Filler] Cache miss for MAL ID: \(malID)", type: "Debug")
        // Prevent duplicate requests
        var shouldFetch = false
        Self.inProgressQueue.sync {
            if !Self.inProgressMALIDs.contains(malID) {
                Self.inProgressMALIDs.insert(malID)
                shouldFetch = true
            }
        }
        
        if !shouldFetch {
            Logger.shared.log("[Filler] Fetch already in progress for MAL ID: \(malID) — skipping", type: "Debug")
            return
        }
        
        Logger.shared.log("[Filler] Fetching Jikan pages for MAL ID: \(malID)", type: "Debug")
        // Fetch all pages
        fetchAllJikanPages(malID: malID) { episodes in
            // store in cache
            if let eps = episodes {
                Logger.shared.log("[Filler] Jikan fetch completed for MAL ID: \(malID) totalEpisodes=\(eps.count)", type: "Debug")
                Self.jikanCacheQueue.async(flags: .barrier) {
                    Self.jikanCache[malID] = (Date(), eps)
                }
            }
            // reset in-progress
            Self.inProgressQueue.sync {
                Self.inProgressMALIDs.remove(malID)
            }
            DispatchQueue.main.async {
                if episodes == nil { Logger.shared.log("[Filler] Jikan fetch failed for MAL ID: \(malID)", type: "Error") }
                if let episodes = episodes {
                    updateFillerSet(episodes: episodes)
                }
            }
        }
    }
    private func fetchAllJikanPages(malID: Int, completion: @escaping ([JikanEpisode]?) -> Void) {
        var allEpisodes: [JikanEpisode] = []
        var currentPage = 1
        let perPage = 100
        var nextAllowedTime = DispatchTime.now()

        func fetchPage() {
            // Throttle to <= 3 req/sec (Jikan limit)
            let now = DispatchTime.now()
            let delay: Double
            if now < nextAllowedTime {
                let diff = Double(nextAllowedTime.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000_000
                delay = max(diff, 0)
            } else {
                delay = 0
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                nextAllowedTime = DispatchTime.now() + .milliseconds(350)

                let url = URL(string: "https://api.jikan.moe/v4/anime/\(malID)/episodes?page=\(currentPage)&limit=\(perPage)")!
                Logger.shared.log("[Filler] Requesting Jikan page #\(currentPage) for MAL ID: \(malID)", type: "Debug")
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let http = response as? HTTPURLResponse
                    let status = http?.statusCode ?? 0

                    struct RetryCounter { static var attempts: [Int: Int] = [:] }
                    let key = currentPage
                    let attempts = RetryCounter.attempts[key] ?? 0

                    let shouldRetry: Bool = (error != nil) || (status == 429) || (status >= 500)
                    if shouldRetry && attempts < 5 {
                        Logger.shared.log("[Filler] Retry page #\(currentPage) attempts=\(attempts+1) status=\(status) error=\(error?.localizedDescription ?? "nil")", type: "Debug")
                        let retryAfterSeconds: Double = {
                            if status == 429, let ra = http?.value(forHTTPHeaderField: "Retry-After"), let v = Double(ra) { return min(v, 5.0) }
                            return min(pow(1.5, Double(attempts)) , 5.0)
                        }()
                        RetryCounter.attempts[key] = attempts + 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + retryAfterSeconds) {
                            fetchPage()
                        }
                        return
                    } else if shouldRetry {
                        Logger.shared.log("[Filler] Giving up page #\(currentPage) status=\(status)", type: "Error")
                        completion(nil)
                        return
                    }

                    guard let data = data else {
                        Logger.shared.log("[Filler] No data for page #\(currentPage)", type: "Error")
                        completion(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(JikanResponse.self, from: data)
                        allEpisodes.append(contentsOf: response.data)
                        if response.data.count == perPage {
                            currentPage += 1
                            fetchPage()
                        } else {
                            Logger.shared.log("[Filler] Finished pagination at page #\(currentPage) total=\(allEpisodes.count)", type: "Debug")
                            completion(allEpisodes)
                        }
                    } catch {
                        Logger.shared.log("[Filler] Decode error page #\(currentPage): \(error.localizedDescription)", type: "Error")
                        completion(nil)
                    }
                }.resume()
            }
        }
        fetchPage()
    }

    private func updateFillerSet(episodes: [JikanEpisode]) {
        let fillerNumbers = Set(episodes.filter { $0.filler }.map { $0.mal_id })
        Logger.shared.log("[Filler] Filler episodes resolved count=\(fillerNumbers.count)", type: "Debug")
        self.jikanFillerSet = fillerNumbers
    }

    // MARK: - TMDB → AniList → MAL resolver
    private func resolveMalIDFromTMDBForAniList() -> Bool {
        Logger.shared.log("[Filler] Resolve MAL via AniList start", type: "Debug")
        guard matchedMalID == nil, let tvShow = tvShow else { return false }
        let titles = [tvShow.name, tvShow.originalName].compactMap { $0 }
        let year = tvShow.firstAirDate.flatMap { Int($0.prefix(4)) }

        let query = """
        query($search: String) {
          Page(page: 1, perPage: 5) {
            media(search: $search, type: ANIME) {
              idMal
              title { romaji english native }
              seasonYear
            }
          }
        }
        """
        guard let url = URL(string: "https://graphql.anilist.co") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let search = titles.first ?? ""
        let body: [String: Any] = ["query": query, "variables": ["search": search]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else {
                Logger.shared.log("[Filler] AniList response empty", type: "Error")
                return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let media = (((json?["data"] as? [String: Any])?["Page"] as? [String: Any])?["media"] as? [[String: Any]]) ?? []

            var bestMal: Int? = nil
            var bestScore = -1
            for m in media {
                guard let idMal = m["idMal"] as? Int, idMal > 0 else { continue }
                let t = m["title"] as? [String: Any]
                let alts = [t?["romaji"] as? String, t?["english"] as? String, t?["native"] as? String]
                    .compactMap { $0?.lowercased() }
                let titleScore = titles.map { $0.lowercased() }.contains(where: { q in alts.contains(q) }) ? 10 : 0
                let yr = m["seasonYear"] as? Int
                let yearScore = (year != nil && yr != nil && abs(yr! - year!) <= 1) ? 5 : 0
                let score = titleScore + yearScore
                if score > bestScore {
                    bestScore = score
                    bestMal = idMal
                }
            }
            DispatchQueue.main.async {
                if let mal = bestMal {
                    Logger.shared.log("[Filler] AniList matched MAL=\(mal) score=\(bestScore)", type: "Debug")
                } else {
                    Logger.shared.log("[Filler] AniList failed to resolve MAL", type: "Error")
                }
                self.matchedMalID = bestMal
                _ = self.fetchJikanFillerInfoIfNeeded()
            }
        }.resume()
        return true
    }
}
