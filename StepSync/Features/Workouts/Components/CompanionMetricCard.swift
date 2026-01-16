import SwiftUI

/// A reusable metric card component for displaying workout statistics
/// in the companion screen (distance, heart rate, calories).
struct CompanionMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(color == .primary ? .secondary : color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        CompanionMetricCard(
            title: "Distance",
            value: "1.24",
            unit: "mi",
            systemImage: "map"
        )

        CompanionMetricCard(
            title: "Heart Rate",
            value: "142",
            unit: "bpm",
            systemImage: "heart.fill",
            color: .red
        )

        CompanionMetricCard(
            title: "Calories",
            value: "156",
            unit: "cal",
            systemImage: "flame.fill",
            color: .orange
        )
    }
    .padding()
}
