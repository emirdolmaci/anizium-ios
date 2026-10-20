import SwiftUI

public struct SplashIntroView: View {
    public let onFinish: () -> Void
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.85
    @State private var hasFinished = false

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "09090B").ignoresSafeArea()

                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: min(geo.size.width, geo.size.height) * 0.45
                        )
                    )
                    .frame(width: min(geo.size.width, geo.size.height) * 0.9)
                    .blur(radius: 20)

                VStack(spacing: 18) {
                    // Intro GIF / Logo Animation
                    let introSize = min(geo.size.width * 0.65, geo.size.height * 0.45, 320.0)

                    ZStack {
                        AnimatedGIFView(assetName: "anizium_intro", contentMode: .scaleAspectFit)
                            .frame(width: introSize, height: introSize * 0.7)
                            .shadow(color: Color.red.opacity(0.6), radius: 24, x: 0, y: 4)
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)

                    VStack(spacing: 6) {
                        Text("ANIZIUM")
                            .font(.system(size: min(geo.size.width * 0.08, 28), weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(4)

                        Text("ANİME VE SİNEMA DÜNYASI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2.5)
                    }
                    .opacity(opacity)
                }
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                finishNow()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.opacity = 1.0
                    self.scale = 1.0
                }

                // Auto dismiss after 1.8 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    finishNow()
                }
            }
        }
    }

    private func finishNow() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}
