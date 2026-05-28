import SwiftUI
import SwiftData

struct ImportInboxSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var manager = ImportInboxManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lucidBlack.ignoresSafeArea()

                if manager.pendingFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.lucidGray.opacity(0.5))
                        Text("No pending imports")
                            .font(.system(size: 16))
                            .foregroundColor(.lucidGray)
                    }
                } else {
                    List {
                        ForEach(manager.pendingFiles) { item in
                            HStack(spacing: 12) {
                                AlbumArtView(data: item.metadata?.albumArt, size: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.metadata?.title ?? item.url.lastPathComponent)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.lucidWhite)
                                        .lineLimit(1)
                                    Text(subtitle(for: item))
                                        .font(.system(size: 13))
                                        .foregroundColor(.lucidGray)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if item.isProcessing {
                                    ProgressView()
                                        .tint(.lucidGreen)
                                } else {
                                    Text(item.metadata?.duration.lucidDurationFormatted ?? "--")
                                        .font(.system(size: 12))
                                        .foregroundColor(.lucidGray)
                                        .monospacedDigit()
                                }

                                Button {
                                    manager.removeItem(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.lucidGray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.lucidBlack)
                            .swipeActions {
                                Button(role: .destructive) {
                                    manager.removeItem(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Import Review (\(manager.pendingFiles.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        manager.clearAll()
                        dismiss()
                    }
                    .foregroundColor(.lucidGray)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        manager.clearAll()
                    }
                    .foregroundColor(.lucidGray)
                    .disabled(manager.pendingFiles.isEmpty)

                    Button("Add All") {
                        manager.confirmImport(modelContext: modelContext)
                        dismiss()
                    }
                    .foregroundColor(.lucidGreen)
                    .fontWeight(.semibold)
                    .disabled(manager.pendingFiles.isEmpty)
                }
            }
        }
    }

    private func subtitle(for item: ImportInboxManager.InboxItem) -> String {
        let artist = item.metadata?.artist ?? "Unknown Artist"
        if let album = item.metadata?.album, !album.isEmpty {
            return "\(artist) · \(album)"
        }
        return artist
    }
}

private extension TimeInterval {
    var lucidDurationFormatted: String {
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
