import SwiftUI

struct ContentView: View {
    @State private var selection: Tab

    enum Tab: Hashable { case scan, search, library }

    init() {
        let args = ProcessInfo.processInfo.arguments
        let initial: Tab
        if args.contains("--launch-tab=library") { initial = .library }
        else if args.contains("--launch-tab=search") { initial = .search }
        else { initial = .scan }
        _selection = State(initialValue: initial)
    }

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
