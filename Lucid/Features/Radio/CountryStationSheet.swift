import SwiftData
import SwiftUI

struct CountryStationSheet: View {
    let country: RadioCountry
    let highlightedStationUUID: String?

    @Environment(\.modelContext) private var modelContext
    @State private var stations: [RadioStation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showComingSoonAlert = false

    init(country: RadioCountry, highlightedStationUUID: String? = nil) {
        self.country = country
        self.highlightedStationUUID = highlightedStationUUID
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        List(stations) { station in
                            StationRowView(
                                station: station,
                                isHighlighted: station.stationuuid == highlightedStationUUID
                            ) {
                                showComingSoonAlert = true
                            }
                            .id(station.stationuuid)
                        }
                        .listStyle(.plain)
                        .onAppear {
                            scrollToHighlightedStation(with: scrollProxy)
                        }
                        .onChange(of: stations.map(\.stationuuid)) { _, _ in
                            scrollToHighlightedStation(with: scrollProxy)
                        }
                    }
                }
            }
            .navigationTitle("\(country.flagEmoji) \(country.countryName)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                header
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await fetchStations()
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Playback will be added in Phase 4")
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
}
