import SwiftUI

enum AppTab: String, Hashable {
    case scan, search, library, feed
}

struct ContentView: View {
    @State private var selection: AppTab

    init() {
        let args = ProcessInfo.processInfo.arguments
        let initial: AppTab
        if args.contains("--launch-tab=library") { initial = .library }
        else if args.contains("--launch-tab=search") { initial = .search }
        else if args.contains("--launch-tab=feed") { initial = .feed }
        else { initial = .scan }
        _selection = State(initialValue: initial)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ScannerView(selectedTab: $selection)
                    .withSocialDestinations(selectedTab: $selection)
            }
            .tabItem { Label("スキャン", systemImage: "barcode.viewfinder") }
            .tag(AppTab.scan)

            NavigationStack {
                SearchView(selectedTab: $selection)
                    .withSocialDestinations(selectedTab: $selection)
            }
            .tabItem { Label("検索", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                LibraryView(selectedTab: $selection)
                    .withSocialDestinations(selectedTab: $selection)
            }
            .tabItem { Label("ライブラリ", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                SocialFeedView()
                    .withSocialDestinations(selectedTab: $selection)
            }
            .tabItem { Label("みんな", systemImage: "building.columns") }
            .tag(AppTab.feed)
        }
    }
}
