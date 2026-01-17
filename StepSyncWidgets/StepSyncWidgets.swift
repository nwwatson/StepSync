import WidgetKit
import SwiftUI

@main
struct StepSyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepProgressWidget()
        QuickStartWidget()
        if #available(iOS 16.1, *) {
            WorkoutLiveActivity()
        }
    }
}
