import SwiftUI

@main
struct MorseBeaconApp: App {
    var body: some Scene {
        WindowGroup {
            BootstrapView()
        }
    }
}

/// Placeholder root view. Replaced by `RootView` once `UI/` is implemented
/// (PRD §3, task tree §3 in TASKS.md).
private struct BootstrapView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Morse Beacon")
                .font(.largeTitle)
                .fontDesign(.monospaced)
            Text("UI scaffolding pending — see TASKS §3")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    BootstrapView()
}
