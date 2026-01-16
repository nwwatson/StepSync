import SwiftUI
import MapKit

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                statsSection

                if let routePoints = workout.routePoints, !routePoints.isEmpty {
                    mapSection(routePoints: routePoints)
                }

                if let heartRateSamples = workout.heartRateSamples, !heartRateSamples.isEmpty {
                    heartRateSection(samples: heartRateSamples)
                }

                if let notes = workout.notes, !notes.isEmpty {
                    notesSection(notes: notes)
                }
            }
            .padding()
        }
        .navigationTitle(workout.workoutType.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: workout.workoutType.systemImage)
                .font(.system(size: 48))
                .foregroundStyle(workout.workoutType == .running ? .orange : .green)

            Text(workout.startDate.formatted(date: .complete, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: workout.environment == .outdoor ? "sun.max" : "building.2")
                Text(workout.environment.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            WorkoutStatCard(
                title: "Duration",
                value: workout.formattedDuration,
                systemImage: "timer"
            )

            WorkoutStatCard(
                title: "Distance",
                value: workout.formattedDistance,
                systemImage: "map"
            )

            WorkoutStatCard(
                title: "Steps",
                value: workout.stepCount.formatted(),
                systemImage: "shoeprints.fill"
            )

            WorkoutStatCard(
                title: "Calories",
                value: String(format: "%.0f", workout.activeCalories),
                systemImage: "flame"
            )

            if let pace = workout.formattedPace {
                WorkoutStatCard(
                    title: "Avg Pace",
                    value: pace,
                    systemImage: "speedometer"
                )
            }

            if let avgHR = workout.averageHeartRate {
                WorkoutStatCard(
                    title: "Avg Heart Rate",
                    value: String(format: "%.0f bpm", avgHR),
                    systemImage: "heart.fill"
                )
            }

            if let cadence = workout.averageCadence {
                WorkoutStatCard(
                    title: "Cadence",
                    value: String(format: "%.0f spm", cadence),
                    systemImage: "metronome"
                )
            }

            if let strideLength = workout.averageStrideLength {
                WorkoutStatCard(
                    title: "Stride Length",
                    value: String(format: "%.2f m", strideLength),
                    systemImage: "ruler"
                )
            }

            if let elevation = workout.elevationGain {
                WorkoutStatCard(
                    title: "Elevation Gain",
                    value: String(format: "%.0f m", elevation),
                    systemImage: "mountain.2"
                )
            }
        }
    }

    private func mapSection(routePoints: [WorkoutRoutePoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)

            Map {
                MapPolyline(coordinates: routePoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(.blue, lineWidth: 4)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func heartRateSection(samples: [HeartRateSample]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate")
                .font(.headline)

            HeartRateChart(samples: samples)
                .frame(height: 150)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        }
    }

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        }
    }
}

struct WorkoutStatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.headline, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}

struct HeartRateChart: View {
    let samples: [HeartRateSample]

    var body: some View {
        let sortedSamples = samples.sorted(by: { $0.timestamp < $1.timestamp })
        let maxHR = sortedSamples.max(by: { $0.beatsPerMinute < $1.beatsPerMinute })?.beatsPerMinute ?? 200
        let minHR = sortedSamples.min(by: { $0.beatsPerMinute < $1.beatsPerMinute })?.beatsPerMinute ?? 60

        GeometryReader { geometry in
            Path { path in
                guard !sortedSamples.isEmpty else { return }

                let width = geometry.size.width
                let height = geometry.size.height
                let range = maxHR - minHR

                for (index, sample) in sortedSamples.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(sortedSamples.count - 1, 1))
                    let normalizedValue = range > 0 ? (sample.beatsPerMinute - minHR) / range : 0.5
                    let y = height * (1 - CGFloat(normalizedValue))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(type: .walking, environment: .outdoor))
    }
}
