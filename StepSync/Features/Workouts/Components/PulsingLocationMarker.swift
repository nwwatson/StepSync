import SwiftUI
import MapKit

/// An animated map annotation showing the current location
/// with a pulsing blue ring effect.
struct PulsingLocationMarker: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)

            // Inner pulsing ring
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.2 : 0.5)

            // Center dot
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)

            // White border
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 14, height: 14)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

/// Map annotation content for the pulsing location marker
struct PulsingLocationAnnotation: MapContent {
    let coordinate: CLLocationCoordinate2D

    var body: some MapContent {
        Annotation("Current Location", coordinate: coordinate) {
            PulsingLocationMarker()
        }
        .annotationTitles(.hidden)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        PulsingLocationMarker()
    }
}
