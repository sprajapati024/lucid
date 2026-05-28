import SwiftData
import SwiftUI

struct CountryStationSheet: View {
    let country: RadioCountry
    let highlightedStationUUID: String?

    @EnvironmentObject private var playerVM: PlayerViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var stations: [RadioStation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playbackErrorMessage: String?
    @State private var sortOrder: StationSortOrder = .popular

    init(country: RadioCountry, highlightedStationUUID: String? = nil) {
        self.country = country
        self.highlightedStationUUID = highlightedStationUUID
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonStationRow()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if stations.isEmpty {
                    ContentUnavailableView(
                        "No Stations",
                        systemImage: "radio",
                        description: Text("No stations are available for this country yet.")
                    )
                } else {
                    ScrollViewReader { scrollProxy in
                        List(sortedStations) { station in
                            StationRowView(
                                station: station,
                                isHighlighted: station.stationuuid == highlightedStationUUID
                            ) {
                                play(station)
                            }
                            .id(station.stationuuid)
                        }
                        .listStyle(.plain)
                        .onAppear {
                            scrollToHighlightedStation(with: scrollProxy)
                        }
                        .onChange(of: sortedStations.map(\.stationuuid)) { _, _ in
                            scrollToHighlightedStation(with: scrollProxy)
                        }
                    }
                }
            }
            .navigationTitle("\(country.flagEmoji) \(country.countryName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await fetchStations()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh stations")
                }
            }
            .safeAreaInset(edge: .top) {
                header
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await fetchStations()
        }
        .alert("Unable to Play Station", isPresented: Binding(
            get: { playbackErrorMessage != nil },
            set: { if !$0 { playbackErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(playbackErrorMessage ?? "The station stream could not be loaded.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 2) {
                Text(country.countryName)
                    .font(.headline)
                Text(country.countryCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Sort", selection: $sortOrder) {
                ForEach(StationSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            Text("\(stations.isEmpty ? country.stationCount : stations.count)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.lucidGreen.opacity(0.2), in: Capsule())
                .foregroundStyle(Color.lucidGreen)
                .accessibilityLabel("\(stations.isEmpty ? country.stationCount : stations.count) stations")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var sortedStations: [RadioStation] {
        let sorted: [RadioStation]

        switch sortOrder {
        case .popular:
            sorted = stations.sorted { lhs, rhs in
                if lhs.clickcount == rhs.clickcount {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.clickcount > rhs.clickcount
            }
        case .recent:
            sorted = stations.sorted { lhs, rhs in
                switch (lhs.lastPlayed, rhs.lastPlayed) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
        case .alphabetical:
            sorted = stations.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        return sorted.sorted { lhs, rhs in
            if lhs.isOffline == rhs.isOffline { return false }
            return !lhs.isOffline && rhs.isOffline
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await fetchStations()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fetchStations() async {
        isLoading = true
        errorMessage = nil

        do {
            stations = try await RadioBrowserService(modelContext: modelContext)
                .fetchStations(forCountryCode: country.countryCode)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func scrollToHighlightedStation(with proxy: ScrollViewProxy) {
        guard let highlightedStationUUID else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                proxy.scrollTo(highlightedStationUUID, anchor: .center)
            }
        }
    }

    private func play(_ station: RadioStation) {
        let streamURLString = station.displayURL

        guard !streamURLString.isEmpty, URL(string: streamURLString) != nil else {
            playbackErrorMessage = "This station does not have a valid stream URL."
            return
        }

        playerVM.playRadioStation(station, modelContext: modelContext)
    }
}

private enum StationSortOrder: String, CaseIterable {
    case popular = "Popular"
    case recent = "Recent"
    case alphabetical = "A-Z"
}

private struct SkeletonStationRow: View {
    @State private var isHighlighted = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(placeholderColor)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(placeholderColor)
                    .frame(width: 180, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(placeholderColor)
                    .frame(width: 120, height: 11)
            }

            Spacer()

            Circle()
                .fill(placeholderColor)
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isHighlighted = true
            }
        }
    }

    private var placeholderColor: Color {
        Color.lucidGray.opacity(isHighlighted ? 0.5 : 0.3)
    }
}
