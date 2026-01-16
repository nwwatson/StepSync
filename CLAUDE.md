# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StepSync is an iOS/watchOS fitness application for tracking daily steps, walking workouts, and running workouts. Built with SwiftUI, SwiftData, and HealthKit.

## Build Commands

```bash
# Build iOS app
xcodebuild -scheme StepSync -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build watchOS app
xcodebuild -scheme StepSyncWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# Run tests
xcodebuild test -scheme StepSync -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build all targets
xcodebuild -scheme "StepSync (All)" build
```

## Architecture

**Pattern**: MVVM + Repository with @Observable macro (iOS 26+/watchOS 26+)

```
Presentation (Views + ViewModels) → Domain (Repositories) → Data (SwiftData + HealthKit)
```

**Targets**:
- `StepSync` - iOS app
- `StepSyncWatch` - watchOS app (independent, syncs via CloudKit)
- `StepSyncShared` - Shared framework (models, services)
- `StepSyncWidgets` - iOS widgets
- `StepSyncWatchWidgets` - watchOS complications

**Key Directories**:
- `StepSyncShared/Models/` - SwiftData models (CloudKit-compatible)
- `StepSyncShared/Services/HealthKit/` - HealthKitManager, WorkoutSessionManager
- `StepSync/Features/` - Feature modules (Dashboard, Steps, Workouts, Insights, Achievements)

## SwiftData + CloudKit Constraints

All models must follow CloudKit rules:
- Properties must be optional OR have default values
- Relationships must be optional
- No `@Attribute(.unique)` - CloudKit doesn't support atomic uniqueness
- Schema changes after deployment are add-only

## HealthKit Data Types

**Read**: stepCount, heartRate, walkingStepLength, walkingSpeed, distanceWalkingRunning, activeEnergyBurned, runningStrideLength, workoutRoute, workoutType

**Write**: stepCount, distanceWalkingRunning, activeEnergyBurned, workoutType

## App Groups & Containers

- Bundle ID: `com.nwwsolutions.stepsync`
- App Group: `group.com.nwwsolutions.steppingszn` (widget data sharing)
- CloudKit Container: `iCloud.com.nwwsolutions.stepsync`

## UI Design

Minimal and modern approach:
- Simple typography-focused design
- Subtle animations
- Clean data visualization
- Neutral color palette with accent colors for progress/achievements

## Testing Notes

- HealthKit requires running on device or simulator with Health app
- CloudKit sync testing requires two devices signed into same iCloud
- Watch independence testing: put iPhone in airplane mode
