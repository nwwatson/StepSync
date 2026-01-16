import WidgetKit
import SwiftUI

@main
struct StepSyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepProgressWidget()
        QuickStartWidget()
    }
}
