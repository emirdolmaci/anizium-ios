import SwiftUI

public struct AnimeCardView: View {
    public let anime: AnimeCard
    public let width: CGFloat

    public init(anime: AnimeCard, width: CGFloat = 130) {
        self.anime = anime
        self.width = width
    }

    private var posterURL: URL? {
        if let link = anime.posterURLString, let url = URL(string: link) {
            return url
        }
        return nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(
                        url: posterURL,
                        targetSize: CGSize(width: width * 2, height: width * 2.9)
                    ) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(hex: "1F1F24"))
                            .overlay(
                                Image(systemName: "film")
                                    .foregroundColor(.white.opacity(0.2))
                                    .font(.title3)
                            )
                    }
                    .frame(width: width, height: width * 1.45)
                    .clipped()
                    .cornerRadius(10)

                    // Bottom subtle gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(width: width, height: width * 0.6)
                    .cornerRadius(10)

                    if let series = anime.type ?? anime.series, !series.isEmpty {
                        Text(series.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(6)
                    }
                }

                // Top right rating badge
                if let score = anime.rating, !score.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Text(score)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(4)
                    .padding(6)
                }
            }

            Text(anime.name ?? "Anime")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
    }
}

// Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
