import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
} 