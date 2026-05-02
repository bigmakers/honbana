import SwiftUI

struct ContentView: View {
    @State private var selection: Tab = .scan

    enum Tab: Hashable { case scan, search, library }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ScannerView()
            }
            .tabItem { Label("スキャン", systemImage: "barcode.viewfinder") }
            .tag(Tab.scan)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("検索", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack {
                LibraryView()
            }
            .tabItem { Label("ライブラリ", systemImage: "books.vertical") }
            .tag(Tab.library)
        }
    }
}
