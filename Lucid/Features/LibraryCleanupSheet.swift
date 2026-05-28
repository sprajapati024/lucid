import SwiftUI
import SwiftData

struct LibraryCleanupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var songs: [Song]
    @State private var issues: [CleanupIssue] = []
    @State private var selectedIssue: CleanupIssue?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if issues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.lucidGreen)
                        Text("Library looks clean!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.lucidWhite)
                        Text("No duplicate songs, missing metadata, or broken artwork found.")
                            .font(.system(size: 14))
                            .foregroundColor(.lucidGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(issues) { issue in
                            Button {
                                selectedIssue = issue
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: iconFor(issue.type))
                                        .foregroundColor(.lucidGreen)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(titleFor(issue.type))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.lucidWhite)
                                        Text(issue.message)
                                            .font(.system(size: 12))
                                            .foregroundColor(.lucidGray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.lucidGray)
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Color.lucidCard)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Library Cleanup")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.lucidGreen)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshIssues()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.lucidGreen)
                    }
                }
            }
            .onAppear(perform: refreshIssues)
            .sheet(item: $selectedIssue) { issue in
                CleanupIssueDetailSheet(issue: issue) {
                    refreshIssues()
                }
            }
        }
    }

    private func refreshIssues() {
        issues = LibraryCleanupManager.shared.findIssues(songs: songs)
    }

    private func iconFor(_ type: CleanupIssue.IssueType) -> String {
        switch type {
        case .duplicateTitle: return "doc.on.doc"
        case .missingMetadata: return "questionmark.circle"
        case .unknownArtist: return "person.fill.questionmark"
        case .brokenArtwork: return "photo"
        }
    }

    private func titleFor(_ type: CleanupIssue.IssueType) -> String {
        switch type {
        case .duplicateTitle: return "Duplicates"
        case .missingMetadata: return "Missing Metadata"
        case .unknownArtist: return "Unknown Artist"
        case .brokenArtwork: return "Missing Artwork"
        }
    }
}

private struct CleanupIssueDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let issue: CleanupIssue
    let onChange: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                List {
                    Section(issue.message) {
                        ForEach(issue.songs) { song in
                            HStack(spacing: 12) {
                                AlbumArtView(data: song.albumArt, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title.isEmpty ? "Missing Title" : song.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.lucidWhite)
                                        .lineLimit(1)
                                    Text(song.artist.isEmpty ? "Missing Artist" : song.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(.lucidGray)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(song.durationFormatted)
                                    .font(.system(size: 12))
                                    .foregroundColor(.lucidGray)
                                    .monospacedDigit()
                            }
                            .listRowBackground(Color.lucidBlack)
                        }
                    }

                    if issue.type == .duplicateTitle, let primary = issue.songs.first {
                        Section {
                            Button(role: .destructive) {
                                LibraryCleanupManager.shared.mergeDuplicates(
                                    primary: primary,
                                    duplicates: Array(issue.songs.dropFirst()),
                                    modelContext: modelContext
                                )
                                onChange()
                                dismiss()
                            } label: {
                                Label("Keep First and Delete Duplicates", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.lucidCard)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.lucidGreen)
                }
            }
        }
    }

    private var title: String {
        switch issue.type {
        case .duplicateTitle: return "Duplicates"
        case .missingMetadata: return "Missing Metadata"
        case .unknownArtist: return "Unknown Artist"
        case .brokenArtwork: return "Missing Artwork"
        }
    }
}
