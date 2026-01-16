# StepSync

A native iOS and watchOS fitness application for tracking daily steps, walking workouts, and running workouts with comprehensive analytics and gamification.

## Features

### Step Tracking
- Real-time daily step count from Apple Health
- Customizable daily step goals
- Achievement-based goal progression (goals increase after consistent achievement)
- Historical step data with trends and insights

### Workouts
- **Walking Workouts** (Indoor/Outdoor)
  - Heart rate monitoring
  - Cadence (steps per minute)
  - Stride length tracking
- **Running Workouts** (Outdoor)
  - GPS route tracking with map overlay
  - Speed over time
  - Total distance
  - Pace analysis

### Analytics & Insights
- Weekly and monthly trend charts
- Pace zone analysis
- Stride length patterns
- Personal records tracking

### Gamification
- Achievement badges
- Streak tracking
- Milestone celebrations

### Apple Watch
- Independent operation (works without iPhone nearby)
- Step count display
- Workout controls
- Complications for step count and quick workout start

### Widgets
- Step goal progress widget
- Interactive workout start widget

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Setup

1. Clone the repository
2. Open `StepSync.xcodeproj` in Xcode
3. Configure signing with your Apple Developer account
4. Capabilities are pre-configured:
   - Bundle ID: `com.nwwsolutions.stepsync`
   - App Groups: `group.com.nwwsolutions.stepsync`
   - HealthKit
   - CloudKit: `iCloud.com.nwwsolutions.stepsync`
5. Build and run

## Architecture

The app uses MVVM with a repository pattern:

- **StepSyncShared**: Shared framework containing models, services, and utilities used by both iOS and watchOS
- **StepSync**: iOS application target
- **StepSyncWatch**: watchOS application target (independent)
- **StepSyncWidgets**: iOS widget extension
- **StepSyncWatchWidgets**: watchOS complications

### Key Technologies
- SwiftUI with @Observable macro
- SwiftData with CloudKit sync
- HealthKit for health data
- MapKit for route visualization
- WidgetKit for widgets and complications
- WatchConnectivity for real-time iPhone/Watch communication

## Privacy

StepSync requires access to:
- **HealthKit**: Read step count, heart rate, walking/running distance, workout routes. Write workouts.
- **Location**: GPS tracking during outdoor workouts only.
- **Notifications**: Goal reminders and achievement alerts.

All data is stored in the user's private iCloud container and never shared with third parties.

## License

Proprietary - All rights reserved.
