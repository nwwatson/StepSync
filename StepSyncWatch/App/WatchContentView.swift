import SwiftUI

struct WatchContentView: View {
    var body: some View {
        NavigationStack {
            TabView {
                WatchDashboardView()

                WatchWorkoutView()

                WatchSummaryView()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

#Preview {
    WatchContentView()
}
