import WidgetKit
import SwiftUI

@main
struct StepSyncWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepCountComplication()
        WorkoutComplication()
    }
}
