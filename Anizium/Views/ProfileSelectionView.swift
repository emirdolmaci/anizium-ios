import SwiftUI

public struct ProfileSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var auth = AuthManager.shared
    @StateObject private var api = AniziumAPI.shared

    @State private var isEditMode = false
    @State private var showCreateSheet = false
    @State private var newProfileName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    // Profile editing
    @State private var editingProfile: ProfileItem?
    @State private var editName = ""
    @State private var isSavingEdit = false
    @State private var showDeleteConfirm = false

    public init() {}

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0E0E10").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 6) {
                            Text(isEditMode ? "Profilleri Yönet" : "Kim İzliyor?")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(isEditMode ? "Düzenlemek veya silmek için bir profile dokunun" : "İzlemeye devam etmek için profilinizi seçin")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 20)

                        if let profiles = auth.currentUser?.profiles, !profiles.isEmpty {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(profiles) { profile in
                                    Button(action: {
                                        if isEditMode {
                                            startEditing(profile)
                                        } else {
                                            auth.selectProfile(profile)
                                            dismiss()
                                        }
                                    }) {
                                        VStack(spacing: 10) {
                                            ZStack(alignment: .topTrailing) {
                                                // Avatar
                                                if let avatarUrlStr = profile.displayAvatar,
                                                   let url = URL(string: avatarUrlStr) {
                                                    AnimatedGIFView(url: url)
                                                        .frame(width: 100, height: 100)
                                                        .cornerRadius(16)
                                                        .clipped()
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .stroke(auth.activeProfile?.id == profile.id ? Color.red : Color.white.opacity(0.15), lineWidth: auth.activeProfile?.id == profile.id ? 3 : 1)
                                                        )
                                                } else {
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.red)
                                                        .frame(width: 100, height: 100)
                                                        .overlay(
                                                            Text(String((profile.name ?? "U").prefix(1)).uppercased())
                                                                .font(.system(size: 36, weight: .bold))
                                                                .foregroundColor(.white)
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .stroke(auth.activeProfile?.id == profile.id ? Color.red : Color.white.opacity(0.15), lineWidth: auth.activeProfile?.id == profile.id ? 3 : 1)
                                                        )
                                                }

                                                // Edit overlay icon
                                                if isEditMode {
                                                    Circle()
                                                        .fill(Color.black.opacity(0.75))
                                                        .frame(width: 32, height: 32)
                                                        .overlay(
                                                            Image(systemName: "pencil")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundColor(.white)
                                                        )
                                                        .padding(6)
                                                } else if auth.activeProfile?.id == profile.id {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 24, height: 24)
                                                        .overlay(
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundColor(.white)
                                                        )
                                                        .padding(6)
                                                }
                                            }

                                            Text(profile.name ?? "Profil")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }

                                // Add Profile Card (Max 4/5 profiles)
                                if (auth.currentUser?.profiles?.count ?? 0) < 5 {
                                    Button(action: { showCreateSheet = true }) {
                                        VStack(spacing: 10) {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                                .frame(width: 100, height: 100)
                                                .overlay(
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 32, weight: .bold))
                                                        .foregroundColor(.white.opacity(0.7))
                                                )

                                            Text("Profil Ekle")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "Bitti" : "Yönet") {
                        withAnimation { isEditMode.toggle() }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            // Create Profile Sheet
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    ZStack {
                        Color(hex: "0E0E10").ignoresSafeArea()
                        VStack(spacing: 20) {
                            Text("Yeni Profil")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.top, 20)

                            TextField("Profil Adı (3 - 16 karakter)", text: $newProfileName)
                                .padding(12)
                                .background(Color(hex: "1F1F24"))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            if let err = errorMessage {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }

                            Button(action: createNewProfile) {
                                if isCreating {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                } else {
                                    Text("Profili Oluştur")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }
                            .disabled(newProfileName.trimmingCharacters(in: .whitespaces).count < 3 || isCreating)
                            .padding(.horizontal, 24)

                            Spacer()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Vazgeç") { showCreateSheet = false }
                                .foregroundColor(.white)
                        }
                    }
                }
                .presentationDetents([.height(260)])
            }
            // Edit Profile Sheet
            .sheet(item: $editingProfile) { profile in
                NavigationStack {
                    ZStack {
                        Color(hex: "0E0E10").ignoresSafeArea()
                        VStack(spacing: 16) {
                            // Avatar Preview & Change Action (NavigationLink)
                            VStack(spacing: 8) {
                                NavigationLink(destination: AvatarPickerView(profileId: profile.ID ?? profile.id) {
                                    if let pid = profile.ID, let updated = auth.currentUser?.profiles?.first(where: { $0.ID == pid }) {
                                        self.editingProfile = updated
                                    }
                                }) {
                                    ZStack(alignment: .bottomTrailing) {
                                        if let avatarUrlStr = profile.displayAvatar, let url = URL(string: avatarUrlStr) {
                                            AnimatedGIFView(url: url)
                                                .frame(width: 86, height: 86)
                                                .cornerRadius(18)
                                                .clipped()
                                        } else {
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color.red)
                                                .frame(width: 86, height: 86)
                                                .overlay(
                                                    Text(String((profile.name ?? "U").prefix(1)).uppercased())
                                                        .font(.system(size: 32, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }

                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                            .offset(x: 4, y: 4)
                                    }
                                }

                                NavigationLink(destination: AvatarPickerView(profileId: profile.ID ?? profile.id) {
                                    if let pid = profile.ID, let updated = auth.currentUser?.profiles?.first(where: { $0.ID == pid }) {
                                        self.editingProfile = updated
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                        Text("Avatarı Değiştir (GIF / Resim Seç)")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 10)

                            TextField("Profil Adı", text: $editName)
                                .padding(12)
                                .background(Color(hex: "1F1F24"))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            Button(action: saveEditedProfile) {
                                if isSavingEdit {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                } else {
                                    Text("Kaydet")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }
                            .disabled(editName.trimmingCharacters(in: .whitespaces).count < 3 || isSavingEdit)
                            .padding(.horizontal, 24)

                            if (auth.currentUser?.profiles?.count ?? 0) > 1 {
                                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                                    Text("Profili Sil")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 6)
                            }

                            Spacer()
                        }
                    }
                    .alert("Profili Sil?", isPresented: $showDeleteConfirm) {
                        Button("İptal", role: .cancel) {}
                        Button("Sil", role: .destructive) { deleteCurrentProfile() }
                    } message: {
                        Text("Bu profil ve izleme geçmişi silinecektir.")
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Kapat") { editingProfile = nil }
                                .foregroundColor(.white)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func startEditing(_ profile: ProfileItem) {
        editingProfile = profile
        editName = profile.name ?? ""
    }

    private func createNewProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 3 && name.count <= 16 else { return }

        isCreating = true
        errorMessage = nil
        Task {
            do {
                try await api.createProfile(name: name)
                await auth.fetchUserDetails()
                await MainActor.run {
                    self.isCreating = false
                    self.showCreateSheet = false
                    self.newProfileName = ""
                }
            } catch {
                await MainActor.run {
                    self.isCreating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveEditedProfile() {
        guard let p = editingProfile, let id = p.ID else { return }
        let name = editName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 3 && name.count <= 16 else { return }

        isSavingEdit = true
        Task {
            do {
                try await api.editProfile(id: id, name: name)
                await auth.fetchUserDetails()
                await MainActor.run {
                    self.isSavingEdit = false
                    self.editingProfile = nil
                }
            } catch {
                await MainActor.run {
                    self.isSavingEdit = false
                }
            }
        }
    }

    private func deleteCurrentProfile() {
        guard let p = editingProfile, let id = p.ID else { return }
        Task {
            do {
                try await api.deleteProfile(id: id)
                await auth.fetchUserDetails()
                await MainActor.run {
                    self.editingProfile = nil
                }
            } catch {
                print("Delete profile error: \(error)")
            }
        }
    }
}
