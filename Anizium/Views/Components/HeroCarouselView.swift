import SwiftUI

public struct HeroCarouselView: View {
    public let items: [SettlementItem]
    public let onSelect: (SettlementItem) -> Void
    @State private var currentIndex = 0

    public var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                ZStack(alignment: .bottomLeading) {
                    // Backdrop Image
                    AsyncImage(url: URL(string: item.banner ?? item.poster ?? "")) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        default:
                            Rectangle()
                                .fill(Color(hex: "18181C"))
                        }
                    }
                    .frame(height: 420)
                    .clipped()

                    // Cinematic Gradient Overlays
                    LinearGradient(
                        colors: [.black.opacity(0.3), .clear, Color(hex: "0E0E10").opacity(0.9), Color(hex: "0E0E10")],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Content overlay
                    VStack(alignment: .leading, spacing: 10) {
                        if let logoUrl = item.logo, let url = URL(string: logoUrl) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 60)
                                } else {
                                    Text(item.name ?? "")
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            Text(item.name ?? "")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.white)
                        }

                        if let overview = item.overview_short ?? item.overview {
                            Text(overview)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                                .shadow(radius: 2)
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                onSelect(item)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                    Text("Hemen İzle")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(8)
                            }

                            if let tmdb = item.tmdb_point {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.yellow)
                                    Text(tmdb)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
                .tag(index)
            }
        }
        .frame(height: 420)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}
