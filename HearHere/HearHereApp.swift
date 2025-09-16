import SwiftUI

@main
struct HearHereApp: App {
    @StateObject private var viewModel = AudioDropViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
