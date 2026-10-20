import SwiftUI
import Combine

public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    @Published public var isLoggedIn: Bool = false
    @Published public var currentUser: UserProfile?
    @Published public var activeProfile: ProfileItem?

    private init() {
        let token = UserDefaults.standard.string(forKey: "user_session")
        self.isLoggedIn = (token != nil && !token!.isEmpty)
        if isLoggedIn {
            Task {
                await fetchUserDetails()
            }
        }
    }

    public func login(token: String) {
        UserDefaults.standard.set(token, forKey: "user_session")
        self.isLoggedIn = true
        Task {
            await fetchUserDetails()
        }
    }

    public func logout() {
        UserDefaults.standard.removeObject(forKey: "user_session")
        self.isLoggedIn = false
        self.currentUser = nil
        self.activeProfile = nil
    }

    public func selectProfile(_ profile: ProfileItem) {
        self.activeProfile = profile
        if let id = profile.ID {
            UserDefaults.standard.set(id, forKey: "active_profile_id")
        }
    }

    public func fetchUserDetails() async {
        do {
            let user = try await AniziumAPI.shared.fetchUser()
            await MainActor.run {
                self.currentUser = user
                if let savedProfileId = UserDefaults.standard.string(forKey: "active_profile_id"),
                   let match = user.profiles?.first(where: { $0.ID == savedProfileId }) {
                    self.activeProfile = match
                } else {
                    self.activeProfile = user.profiles?.first
                }
            }
        } catch {
            print("Fetch user details error: \(error)")
        }
    }
}
