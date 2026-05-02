import SwiftUI
import SwiftData

@main
struct BarcodeReviewApp: App {
    let container: ModelContainer

    init() {
        container = try! ModelContainer(for: SavedBook.self, MemoImage.self)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-screenshots") {
            ScreenshotSeeder.seedIfNeeded(in: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .modelContainer(container)
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let isbn = launchDetailISBN() {
            NavigationStack {
                BookDetailView(isbn13: isbn)
            }
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }

    #if DEBUG
    private func launchDetailISBN() -> String? {
        for arg in ProcessInfo.processInfo.arguments {
            if arg.hasPrefix("--launch-detail=") {
                return String(arg.dropFirst("--launch-detail=".count))
            }
        }
        return nil
    }
    #endif
}
