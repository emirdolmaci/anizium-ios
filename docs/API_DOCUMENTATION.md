# anizium.co Resmi API ve Güvenlik Protokolü Dökümantasyonu 📡

Bu belge, Anizium iOS istemcisinin [anizium.co](https://anizium.co) sunucularıyla haberleşirken kullandığı şifreleme algoritmalarını, oturum protokollerini ve tüm API uç noktalarını açıklar.

---

## 1. Ağ Mimarisi ve Temel Başlıklar (HTTP Headers)

Tüm istekler `https://api.anizium.co` temel adresine yapılır (Yedek adres: `https://api.anizium.online`).  
Her HTTP isteğinde aşağıdaki standart başlıkların bulunması zorunludur:

| Başlık (Header) | Değer | Açıklama |
|---|---|---|
| `Accept` | `application/json` | JSON formatında yanıt talebi |
| `Content-Type` | `application/json` | Gönderilen verinin türü |
| `User-Agent` | `Anizium/2.1.0 (iOS)` | İstemci tanımlayıcısı |
| `device` | `browser` | İstemci cihaz tipi |
| `language` | `tr` | İçerik ve hata mesajları dili |
| `site` | `main` | Ana site kapsamı |
| `Cf-Control` | `[Dinamik Şifreli Metin]` | Cloudflare ve anlık zaman doğrulama başlığı |
| `user-session` | `[Oturum Tokenı]` | Giriş yapılmışsa oturum anahtarı (Opsiyonel) |
| `user-profile` | `[Profil ID]` | Giriş yapılmışsa aktif izleyici profili (Opsiyonel) |

---

## 2. Kriptografik Güvenlik Protokolleri

### A. Dinamik `Cf-Control` Başlığı Oluşturma
Her istek için istemcinin güncel zaman ve haftanın günü bilgisiyle XOR şifrelemesi üretilir:

```text
1. now = Tarih (Europe/Istanbul zaman dilimi)
2. dayName = now.strftime('%A').toLowerCase()  (örn: "tuesday")
3. randKey = 6 haneli rastgele alfanumerik metin
4. millis = now zaman damgası (milisaniye)
5. jsonPayload = {"<randKey>": <millis>}
6. xorKey = "hlxjl1c2w281ax473rt1ofgrvhyjvi_" + dayName
7. encrypted = payloadBytes XOR xorKey (döngüsel)
8. Cf-Control = Base64(encrypted)
```

### B. İstek Gövdesi (Body) Şifreleme (`d` Parametresi)
POST isteklerinde gönderilen hassas parametreler (giriş bilgileri, profil yönetimi, yorumlar vb.) istemci anahtarıyla XOR şifrelemesinden geçirilerek hex formatında iletilir:

```text
İstemci Anahtarı: "16ghkdz5qnwinkyebwopbd94b49xhs"
Gövde Formatı: {"d": "<HexEncodedEncryptedPayload>"}
```

---

## 3. Uç Noktalar (Endpoints)

### 🔑 Kullanıcı ve Oturum
- **`POST /user/login`**: Kullanıcı adı/e-posta ve şifre ile giriş. Yanıtta `session` tokenı ve kullanıcı profilleri döner.
- **`POST /user/register`**: Yeni kullanıcı kaydı.
- **`GET /user/get`**: Mevcut oturum bilgilerini, kullanıcı yetkilerini, premium durumunu ve profilleri yeniler.

### 👤 Profil Yönetimi ("Kim İzliyor?")
- **`POST /user/profile/manage`**:
  - Profil Ekleme: `{ "action": "create", "name": "Emir" }`
  - Profil Düzenleme: `{ "action": "edit", "id": "<id>", "name": "Yeni İsim" }`
- **`POST /user/profile/delete`**:
  - Profil Silme: `{ "id": "<id>" }`
- **`POST /user/profile/avatar`**:
  - Avatar Güncelleme: `{ "id": "<id>", "avatar_set": "<avatar_path.gif>" }`
  - Avatar Sıfırlama: `{ "id": "<id>", "avatar_set": "delete" }`

### 🎨 Avatarlar Kataloğu
- **`GET /page/avatar-list`**:
  - Parametreler: `page` (1, 2, 3...), `query` (arama terimi, örn: `Luffy`, `Titan`).
  - Yanıtta anime serilerine göre gruplandırılmış, hem hareketli `.gif` hem de statik `.webp` karakter avatarları döner.

### 🎬 İçerik & Yayın Akışı
- **`GET /page/home`**: Ana sayfa üst karuseli (`settlement_top`), özel listeler (`special_list`), öne çıkanlar.
- **`GET /anime/get?id=<anime_id>`**: Anime künyesi, sezonlar, bölümler, özet, puanlar.
- **`GET /anime/source?id=<anime_id>&server=1`**: Bölümün veya filmin doğrudan oynatılabilir HLS `.m3u8` veya `.mp4` video akışı kaynakları.
- **`GET /page/search?query=<metin>`**: Canlı anime ve film arama motoru.
- **`GET /page/calendar`**: Günlük ve haftalık anime yayın takvimi.
- **`GET /page/random-anime`**: Rastgele anime ID önerisi.

### ⏱️ İzleme Geçmişi & Yorumlar
- **`GET /page/keep-watching`**: Kaldığın yerden devam et listesi ve bölüm ilerleme çubuğu.
- **`POST /anime/keep-watching/save`**: İlerleme süresi kaydı (`anime_id`, `season`, `episode`, `current_time`).
- **`GET /comment/list?id=<anime_id>&page=1`**: Anime yorumları.
- **`POST /comment/send`**: Yorum ve spoiler gönderimi.

### 👑 Premium Üyelik
- **`GET /page/premium`**: Üyelik planları (1 Ay, 3 Ay, 6 Ay, 1 Yıl, Sınırsız).
- **`POST /premium/gift-code/use`**: Hediye kodu aktivasyonu.
