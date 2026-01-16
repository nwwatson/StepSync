import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var completedColor: Color = .green
    var inProgressColor: Color = .primary
    var backgroundColor: Color = .secondary.opacity(0.2)

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progress >= 1.0 ? completedColor : inProgressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.8), value: progress)
        }
    }
}

struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var completedColor: Color = .green
    var inProgressColor: Color = .primary
    var backgroundColor: Color = .secondary.opacity(0.2)

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    animatedProgress >= 1.0 ? completedColor : inProgressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = min(newValue, 1.0)
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ProgressRing(progress: 0.75, lineWidth: 20)
            .frame(width: 150, height: 150)

        ProgressRing(progress: 1.0, lineWidth: 20)
            .frame(width: 150, height: 150)

        AnimatedProgressRing(progress: 0.5, lineWidth: 15)
            .frame(width: 100, height: 100)
    }
    .padding()
}
