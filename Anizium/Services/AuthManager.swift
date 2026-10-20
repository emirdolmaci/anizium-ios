import SwiftUI
import Combine

public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    @Published public var isLoggedIn: Bool = false
    @Published public var currentUser: UserProfile?
    @Published public var activeProfile: ProfileItem?

    public var savedUsername: String {
        UserDefaults.standard.string(forKey: "saved_auth_username") ?? ""
    }

    public var savedPassword: String {
        UserDefaults.standard.string(forKey: "saved_auth_password") ?? ""
    }

    private init() {
        let token = UserDefaults.standard.string(forKey: "user_session")
        if let token = token, !token.isEmpty {
            self.isLoggedIn = true
            Task {
                await fetchUserDetails()
            }
        } else if !savedUsername.isEmpty && !savedPassword.isEmpty {
            Task {
                await performAutoLogin()
            }
        }
    }

    public func login(token: String, username: String? = nil, password: String? = nil, remember: Bool = true) {
        UserDefaults.standard.set(token, forKey: "user_session")
        if remember {
            if let u = username, !u.isEmpty {
                UserDefaults.standard.set(u, forKey: "saved_auth_username")
            }
            if let p = password, !p.isEmpty {
                UserDefaults.standard.set(p, forKey: "saved_auth_password")
            }
        }
        self.isLoggedIn = true
        Task {
            await fetchUserDetails()
        }
    }

    public func logout() {
        UserDefaults.standard.removeObject(forKey: "user_session")
        UserDefaults.standard.removeObject(forKey: "saved_auth_password")
        self.isLoggedIn = false
        self.currentUser = nil
        self.activeProfile = nil
    }

    public func performAutoLogin() async {
        guard !savedUsername.isEmpty && !savedPassword.isEmpty else { return }
        do {
            let res = try await AniziumAPI.shared.login(value: savedUsername, password: savedPassword)
            if let session = res.session, !session.isEmpty {
                await MainActor.run {
                    self.login(token: session, username: self.savedUsername, password: self.savedPassword, remember: true)
                }
            }
        } catch {
            print("Auto login failed: \(error)")
        }
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
                } else if let firstProfile = user.profiles?.first {
                    self.activeProfile = firstProfile
                    if let id = firstProfile.ID {
                        UserDefaults.standard.set(id, forKey: "active_profile_id")
                    }
                }
            }
        } catch {
            print("Fetch user details error: \(error)")
            // If session expired or unauthorized, attempt background auto re-login
            await performAutoLogin()
        }
    }
}
