import SwiftUI

struct ContentView: View {
    @Environment(WorkoutMirroringManager.self) private var mirroringManager

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard
        case workouts
        case insights
        case achievements
        case settings

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .workouts: return "Workouts"
            case .insights: return "Insights"
            case .achievements: return "Achievements"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .dashboard: return "figure.walk"
            case .workouts: return "heart.circle"
            case .insights: return "chart.bar.xaxis"
            case .achievements: return "trophy"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.systemImage)
                }
                .tag(Tab.dashboard)

            WorkoutListView()
                .tabItem {
                    Label(Tab.workouts.title, systemImage: Tab.workouts.systemImage)
                }
                .tag(Tab.workouts)

            InsightsView()
                .tabItem {
                    Label(Tab.insights.title, systemImage: Tab.insights.systemImage)
                }
                .tag(Tab.insights)

            AchievementsView()
                .tabItem {
                    Label(Tab.achievements.title, systemImage: Tab.achievements.systemImage)
                }
                .tag(Tab.achievements)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
                }
                .tag(Tab.settings)
        }
        .tint(.primary)
        .fullScreenCover(isPresented: .init(
            get: { mirroringManager.isWatchInitiatedWorkout && mirroringManager.isMirroring },
            set: { _ in }
        )) {
            NavigationStack {
                WatchWorkoutCompanionView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WorkoutMirroringManager.shared)
}
