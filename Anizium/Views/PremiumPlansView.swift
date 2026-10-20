import SwiftUI

public struct PremiumPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = AniziumAPI.shared
    @StateObject private var auth = AuthManager.shared

    @State private var plans: [PremiumPlanData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Gift code redemption state
    @State private var giftCodeText = ""
    @State private var isRedeemingCode = false
    @State private var giftCodeAlertMessage: String?
    @State private var showGiftCodeAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.red).scaleEffect(1.2)
                        Text("Premium paketleri yükleniyor...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.white.opacity(0.8))
                        Button("Tekrar Dene") { loadPlans() }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Current Subscription Status Header (if logged in)
                            if auth.isLoggedIn {
                                CurrentUserPremiumHeader()
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                            }

                            // Gift Code Redemption Bar
                            GiftCodeCard(
                                codeText: $giftCodeText,
                                isSubmitting: isRedeemingCode,
                                onRedeem: redeemGiftCode
                            )
                            .padding(.horizontal, 16)

                            // Title & Description
                            VStack(spacing: 6) {
                                Text("Ayrıcalıklı Anime Deneyimi")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.white)
                                Text("4K Ultra HD kalitede, reklamsız, çoklu dublaj ve altyazı ile izleyin.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 6)

                            // Plans List
                            VStack(spacing: 16) {
                                ForEach(plans) { plan in
                                    PlanCardView(plan: plan)
                                }
                            }
                            .padding(.horizontal, 16)

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationTitle("Premium Üyelik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Hediye Kodu", isPresented: $showGiftCodeAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(giftCodeAlertMessage ?? "")
            }
        }
        .onAppear {
            loadPlans()
        }
    }

    private func loadPlans() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await api.fetchPremiumPlans()
                await MainActor.run {
                    self.plans = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func redeemGiftCode() {
        let code = giftCodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        isRedeemingCode = true
        Task {
            do {
                let msg = try await api.useGiftCode(code: code)
                await auth.fetchUserDetails()
                await MainActor.run {
                    self.giftCodeAlertMessage = msg
                    self.showGiftCodeAlert = true
                    self.giftCodeText = ""
                    self.isRedeemingCode = false
                }
            } catch {
                await MainActor.run {
                    self.giftCodeAlertMessage = error.localizedDescription
                    self.showGiftCodeAlert = true
                    self.isRedeemingCode = false
                }
            }
        }
    }
}

// Current User Premium Header
struct CurrentUserPremiumHeader: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: auth.currentUser?.isPremium == true ? "crown.fill" : "person.fill")
                        .foregroundColor(auth.currentUser?.isPremium == true ? .yellow : .white.opacity(0.6))
                    Text(auth.currentUser?.isPremium == true ? auth.currentUser!.planDisplayName : "Ücretsiz Üye")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                if auth.currentUser?.isPremium == true {
                    Text(auth.currentUser?.infinity == true ? "Süresiz" : "Aktif")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if auth.currentUser?.isPremium == true {
                HStack {
                    Text("⏳ Kalan Süren:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(auth.currentUser?.remainingPremiumText ?? "Yok")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "1F1F24"))
        .cornerRadius(10)
    }
}

// Gift Code Card
struct GiftCodeCard: View {
    @Binding var codeText: String
    let isSubmitting: Bool
    let onRedeem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .foregroundColor(.red)
                Text("Hediye Kodu Kullan")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 8) {
                TextField("Kodunuzu girin...", text: $codeText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(hex: "292930"))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: onRedeem) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(8)
                    } else {
                        Text("Uygula")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .disabled(codeText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            }
        }
        .padding(14)
        .background(Color(hex: "1F1F24"))
        .cornerRadius(10)
    }
}

// Plan Card View
struct PlanCardView: View {
    let plan: PremiumPlanData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Name & Badge
            HStack {
                Text(plan.name ?? "Plan")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)

                if plan.isInfinity {
                    Text("SINIRLI")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(4)
                } else if plan.value == "standart" {
                    Text("ÖNERİLEN")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.yellow)
                        .cornerRadius(4)
                }

                Spacer()

                Text(plan.day_text ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Price & Discount
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let price = plan.view_price {
                    Text(String(format: "%.2f TL", price))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }

                if let disc = plan.discount, disc.active == true, let orig = disc.original_price {
                    Text(String(format: "%.2f TL", orig))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .strikethrough()

                    if let pct = disc.percent {
                        Text("%\(pct) İndirim")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Advantages list
            if let advantages = plan.advantages {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(advantages, id: \.self) { adv in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(plan.isInfinity ? .yellow : .red)
                                .padding(.top, 2)
                            Text(adv)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }

            // Purchase Buttons (Alternatives from API: Shopier, Itemsatis, Gumroad)
            if let alts = plan.alternatives, !alts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(alts) { alt in
                        if let url = URL(string: alt.link) {
                            Link(destination: url) {
                                Text(alt.platformName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(plan.isInfinity ? Color.red : Color.white.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            } else if let url = URL(string: "https://anizium.co/premium") {
                Link(destination: url) {
                    Text("anizium.co Üzerinden Satın Al")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.red)
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "1F1F24"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(plan.isInfinity ? Color.red.opacity(0.6) : Color.white.opacity(0.08), lineWidth: plan.isInfinity ? 2 : 1)
                )
        )
    }
}
