import SwiftData
import SwiftUI

struct RadioView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RadioGlobeViewModel?
    @State private var sheetCountry: RadioCountry?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    RadioGlobeView(viewModel: viewModel)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel?.selectedCountry?.persistentModelID) { _, _ in
                sheetCountry = viewModel?.selectedCountry
            }
            .sheet(item: $sheetCountry, onDismiss: {
                viewModel?.clearSelection()
            }) { country in
                CountryStationSheet(country: country)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = RadioGlobeViewModel(modelContext: modelContext)
                }
            }
        }
    }
}
