// Apple's canonical Liquid Glass minimum: SwiftUI App + WindowGroup +
// .glassEffect() on cards + .buttonStyle(.glass).
// The WindowGroup handles all the macOS 26 Tahoe chrome opt-in for us.
import SwiftUI

@main
struct LiquidGlassDemo: App {
    var body: some Scene {
        WindowGroup("Liquid Glass Demo") {
            DemoView()
        }
        .defaultSize(width: 720, height: 520)
    }
}

struct DemoView: View {
    @State private var selection: Int?

    var body: some View {
        ZStack {
            // A vivid backdrop so we can SEE the glass blur it.
            LinearGradient(
                colors: [.purple, .blue, .teal, .green, .yellow, .orange, .pink],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Liquid Glass Demo")
                    .font(.system(size: 28, weight: .bold))
                    .padding()
                    .glassEffect()

                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(0..<3) { i in
                            HStack {
                                Image(systemName: ["display", "laptopcomputer", "tv"][i])
                                    .font(.title)
                                VStack(alignment: .leading) {
                                    Text(["Built-in", "BenQ GL2480", "Workshop Projector"][i])
                                        .font(.headline)
                                    Text(["2560×1664", "1920×1080", "1280×720"][i])
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selection == i {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassEffect(
                                .regular.tint(selection == i ? .accentColor : nil).interactive(),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .onTapGesture { selection = i }
                        }
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button("Cycle") {}.buttonStyle(.glass)
                    Button("Apply") {}.buttonStyle(.glassProminent)
                }
                .padding()

                Spacer()
            }
            .padding(24)
        }
    }
}
