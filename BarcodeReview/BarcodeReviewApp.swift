import SwiftUI
import SwiftData

@main
struct BarcodeReviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SavedBook.self, MemoImage.self])
    }
}
