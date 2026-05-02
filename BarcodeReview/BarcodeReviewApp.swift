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
            ContentView()
        }
        .modelContainer(container)
    }
}
