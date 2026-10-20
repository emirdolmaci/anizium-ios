# Anizium iOS & Apple Universal 🎬

[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B%20%7C%20iPadOS%2016%2B%20%7C%20macOS%2012%2B%20%7C%20visionOS%201%2B-blue.svg)](https://github.com/emirdolmaci/anizium-ios)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15%2B%20%7C%2016%2B-1575F9.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI Build](https://github.com/emirdolmaci/anizium-ios/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/emirdolmaci/anizium-ios/actions)

[anizium.co](https://anizium.co) platformunun resmi API altyapısına doğrudan bağlanan, modern **SwiftUI** mimarisiyle sıfırdan geliştirilmiş, donanım hızlandırmalı video oynatımı sunan evrensel Apple istemcisi.

iPhone, iPad (Split View & Stage Manager), Apple Silicon Mac (M1/M2/M3/M4) ve Apple Vision Pro cihazlarının tümünde kusursuz çalışacak şekilde tasarlanmıştır.

---

## 🌟 Öne Çıkan Özellikler

### 🔐 1. Resmi anizium.co API & Uçtan Uca Şifreleme
* Doğrudan `api.anizium.co` altyapısına bağlanır.
* Tüm hassas istekler (giriş, profil yönetimi, liste güncelleme, yorumlar) `16ghkdz5qnwinkyebwopbd94b49xhs` istemci anahtarıyla şifrelenir.
* `user-session` ve `user-profile` header bazlı oturum sürekliliği.

### 👤 2. "Kim İzliyor?" Profil Seçimi ve Yönetimi
* `https://anizium.co/profiles` web arayüzünün tam işlevsel native eşdeğeri.
* Çoklu profil desteği (Örn: Emir, Misafir, vb.).
* Yeni profil oluşturma, profil ismi düzenleme, profil silme (`/user/profile/manage`, `/user/profile/delete`).
* Hareketli GIF avatar desteği ve aktif profil senkronizasyonu.
* Ana sayfadan tek dokunuşla profil değiştirme.

### 🎥 3. Gelişmiş Video Oynatıcı & Picture-in-Picture (PiP)
* **Otomatik PiP (Resim İçinde Resim)**: Video oynatılırken uygulama arka plana alındığında veya başka bir sekmeye geçildiğinde oynatıcı otomatik olarak küçük açılır pencere (PiP) olarak yayına devam eder.
* **Canlı Altyazı Özelleştirici (`SubtitleSettingsModal`)**:
  * **Yazı Boyutu**: 14pt ile 26pt arasında dinamik boyutlandırma.
  * **Yazı Rengi**: Sarı (`#FFD700`), Beyaz (`#FFFFFF`), Camgöbeği (`#00FFFF`), Yeşil (`#00FF88`).
  * **Arka Plan Stili**: Yarı Saydam Siyah, Opak Siyah veya Kutusuz (Metin Gölgesi).
  * **Dikey Konum Ayarı**: Standart alt veya +30pt yukarıda altyazı konumu.
  * Oynatıcı içerisinden canlı önizlemeli modal ile anlık değişim ve kalıcı (`@AppStorage`) kayıt.
* HLS / Adaptive bitrate desteği (1080p, 720p, 480p, 360p).
* Otomatik intro geçme ve sonraki bölüme otomatik atlama.

### 📅 4. Canlı Yayın Takvimi
* `api.anizium.co/calendar` ile anlık güncellenen haftalık anime yayın akışı.
* Günlere göre sekmeli gezinme ve yayınlanan bölümlere doğrudan erişim.

### 🔍 5. Akıllı Keşfet & İki Yönlü Arama
* 300ms debounce mekanizmalı, sunucuyu yormayan anlık arama.
* Tüm anime, film ve dizi arşivinde eşzamanlı sorgulama.

### 👑 6. Premium Üyelik & Avantajlar
* `https://anizium.co/premium` ile birebir uyumlu planlar (1 Ay, 3 Ay, 6 Ay, 1 Yıl, Sınırsız).
* Kalan gün sayacı, sonsuz üyelik rozeti, premium kod aktivasyonu.

### 📱 7. Evrensel Ekran Uyumu (Adaptive Layout)
* `GridItem(.adaptive)` ile dinamik kolon yapısı:
  * **iPhone**: 3 kolonlu ergonomik tek el görünümü.
  * **iPad**: 5-8 kolonlu geniş ekran katalog görünümü (Split View & Stage Manager destekli).
  * **Mac**: 6-10 kolonlu masaüstü pencereleme görünümü.
  * **Apple Vision Pro**: 4K uzamsal pencere görünümü.

---

## 📦 Kurulum Rehberi (IPA & DMG)

Son derlenmiş sürümleri [Releases](https://github.com/emirdolmaci/anizium-ios/releases/tag/v2.1.0) sayfasından indirebilirsiniz:
* **iOS / iPadOS**: `Anizium.ipa`
* **macOS (Apple Silicon)**: `Anizium.dmg` veya `Anizium.ipa`

---

### Yöntem 1: 3uTools ile IPA Yükleme (Windows / Mac) 🛠️

3uTools, bilgisayarınız üzerinden ücretsiz Apple ID'nizle IPA imzalayıp iPhone veya iPad'inize yüklemenin en pratik yoludur.

1. **3uTools Programını İndirin**: Bilgisayarınıza [3uTools](http://www.3u.com/) programını kurun ve açın.
2. **Cihazınızı Bağlayın**: iPhone veya iPad'inizi USB kablosuyla bilgisayara bağlayın. Cihaz ekranında çıkan **"Bu Bilgisayara Güven"** uyarısını onaylayıp parolanızı girin.
3. **İmza Aracını Açın**: 3uTools üst menüsünden **Araçlar (Toolbox)** sekmesine gelin, ardından **IPA İmzala (IPA Signature)** seçeneğine tıklayın.
4. **IPA Dosyasını Seçin**: **IPA Ekle (Add IPA)** butonuna basarak indirdiğiniz `Anizium.ipa` dosyasını seçin.
5. **Apple ID Ekleyin**:
   * **"Apple Kimliği ile İmzala (Sign with Apple ID)"** seçeneğini işaretleyin.
   * **Apple ID Ekle** butonuna basarak kendi Apple ID'nizi ve parolanızı girin (Ücretsiz bireysel hesap yeterlidir).
6. **İmzalamayı Başlatın**: Listeden `Anizium.ipa` ve eklediğiniz Apple ID'yi işaretleyip **İmzalamayı Başlat (Start Signing)** butonuna tıklayın. Birkaç saniye içinde durum yeşil renkte *"Başarılı"* olacaktır.
7. **Cihaza Yükleyin**: İmzalanan dosyanın sağındaki klasör ikonuna tıklayın veya 3uTools ana ekranındaki **Uygulamalar (Apps)** sekmesine gelip imzalanmış IPA'yı cihazınıza yükleyin.
8. **Geliştirici İzni Verin (Son Adım)**:
   * iPhone/iPad cihazınızda **Ayarlar** -> **Genel** -> **VPN ve Aygıt Yönetimi** yolunu izleyin.
   * Geliştirici Uygulaması altında kendi Apple ID'nizi göreceksiniz. Dokunun ve **"Güven"** butonuna basın.
   * *(iOS 16+ için)*: **Ayarlar** -> **Gizlilik ve Güvenlik** -> en alttaki **Geliştirici Modu**'nu açıp cihazı yeniden başlatın.
   * Artık **Anizium** ana ekranınızda açılmaya hazırdır!

---

### Yöntem 2: AltStore / SideStore ile Yükleme (Kablosuz & Otomatik Yenileme)

1. Bilgisayarınızda AltServer açıkken cihazınıza AltStore uygulamasını kurun.
2. Cihazınızın Safari tarayıcısından [Releases](https://github.com/emirdolmaci/anizium-ios/releases) sayfasındaki `Anizium.ipa` dosyasını indirin.
3. AltStore uygulamasında **My Apps** sekmesine gelin, sol üstteki **"+"** ikonuna basıp `Anizium.ipa` dosyasını seçin.
4. Kurulum tamamlandıktan sonra uygulama 7 gün boyunca kesintisiz çalışır; aynı Wi-Fi ağındayken otomatik yenilenir.

---

### Yöntem 3: Sideloadly ile Yükleme (Windows / macOS)

1. [Sideloadly](https://sideloadly.io/) programını bilgisayarınıza kurun.
2. Cihazınızı USB ile bağlayın.
3. `Anizium.ipa` dosyasını Sideloadly penceresine sürükleyip bırakın.
4. Apple ID bilgilerinizi girin ve **Start** butonuna basın.
5. Cihazınızda **Ayarlar** -> **Genel** -> **VPN ve Aygıt Yönetimi** sekmesinden profilinizi onaylayın.

---

### Yöntem 4: TrollStore ile Yükleme (Süresiz & İmzasız)

Eğer iOS 14.0 - 16.6.1 / 17.0 arasında TrollStore destekleyen bir sürümdeyseniz:
1. `Anizium.ipa` dosyasını indirin.
2. Dosyayı TrollStore ile açın ve **Install** seçeneğine dokunun.
3. 7 gün sınırı veya imzalama gereksinimi olmadan kalıcı olarak yüklenir.

---

### Yöntem 5: macOS Apple Silicon (M1/M2/M3/M4) Kurulumu 💻

Apple Silicon çipli Mac bilgisayarlarda iPad uygulamaları yerel olarak çalıştırılabilir.

1. **DMG ile Kurulum**:
   * [Releases](https://github.com/emirdolmaci/anizium-ios/releases) sayfasından `Anizium.dmg` dosyasını indirin.
   * DMG dosyasına çift tıklayarak açın ve `Anizium.app` ikonunu `Applications` klasörüne sürükleyin.
   * Uygulamayı ilk kez açarken macOS güvenlik uyarısı verirse:
     Terminal uygulamasını açıp şu komutu girin:
     ```bash
     xattr -cr /Applications/Anizium.app
     ```
     veya **Sistem Ayarları** -> **Gizlilik ve Güvenlik** -> **"Yine de Aç"** butonuna tıklayın.
2. **PlayCover ile Kurulum**:
   * Mac'inizde [PlayCover](https://playcover.io/) kuruluysa, `Anizium.ipa` dosyasını PlayCover arayüzüne sürükleyip tam klavye/fare eşleme desteğiyle çalıştırabilirsiniz.

---

## 🛠️ Kaynak Kod Mimarisi (Source Code Structure)

Geliştiriciler için proje dosya hiyerarşisi:

```text
Anizium-iOS/
├── Anizium/
│   ├── AniziumApp.swift                 # SwiftUI Lifecycle Giriş Noktası
│   ├── Info.plist                       # Cihaz izinleri, aile tanımları (1, 2) ve yönelimler
│   ├── Models/
│   │   └── AniziumModels.swift          # Anime, Bölüm, Profil, Yorum, Takvim veri modelleri
│   ├── Services/
│   │   ├── AniziumAPI.swift             # Uçtan uca şifreli HTTP servis katmanı
│   │   ├── AuthManager.swift            # Oturum, Keychain, aktif profil yöneticisi
│   │   └── ImageCacheService.swift      # Disk ve RAM bazlı 2 kademeli görsel önbellek
│   ├── Views/
│   │   ├── MainTabView.swift            # Ana navigasyon ve sekme çubuğu
│   │   ├── HomeView.swift               # Karusel, devam et listesi, özel koleksiyonlar
│   │   ├── SearchView.swift             # Keşfet ve anlık arama motoru
│   │   ├── CalendarView.swift           # Yayın takvimi sekmesi
│   │   ├── WatchlistView.swift          # Kullanıcı izleme listesi
│   │   ├── AnimeDetailView.swift        # Anime detayları, bölümler, yorumlar
│   │   ├── PlayerView.swift             # AVPlayer, otomatik PiP, altyazı özelleştirici
│   │   ├── ProfileSelectionView.swift   # "Kim İzliyor?" profil yönetimi
│   │   ├── SettingsView.swift           # Kullanıcı profili, premium durumu, ayarlar
│   │   ├── Auth/
│   │   │   └── LoginSheetView.swift     # anizium.co giriş yapma modalı
│   │   └── Components/
│   │       ├── AnimeCardView.swift      # Uyarlanabilir anime kart bileşeni
│   │       ├── HeroCarouselView.swift   # Ana sayfa öne çıkanlar kaydırıcısı
│   │       └── PremiumPlansView.swift   # Üyelik planları ve kod aktivasyon ekranı
│   └── Assets.xcassets/                 # Vektör ikonlar ve renk paleti
├── Anizium.xcodeproj/                   # Xcode proje dosyası (PBX Native Target)
├── .github/workflows/build-ipa.yml      # CI/CD: Otomatik IPA ve DMG derleme hattı
├── LICENSE                              # MIT Lisansı
└── README.md                            # Kapsamlı dökümantasyon
```

---

## 🏗️ Manuel Derleme (Xcode & CLI)

Projeyi kendi ortamınızda derlemek isterseniz:

```bash
# Depoyu klonlayın
git clone https://github.com/emirdolmaci/anizium-ios.git
cd anizium-ios

# Xcode ile açın
open Anizium.xcodeproj
```

Komut satırı üzerinden imzasız derleme:

```bash
xcodebuild -project Anizium.xcodeproj \
           -scheme Anizium \
           -configuration Release \
           -sdk iphoneos \
           -destination 'generic/platform=iOS' \
           build \
           CODE_SIGNING_ALLOWED=NO
```

---

## ⚖️ Lisans

Bu proje **MIT Lisansı** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
Tüm anime içerikleri ve telif hakları [anizium.co](https://anizium.co) ve ilgili hak sahiplerine aittir.
