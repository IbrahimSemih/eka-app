# 🔥 Firebase Console Kurulum Rehberi (Türkçe)

## 🎯 Genel Bakış

Bu rehber, EKA uygulamasını Firebase ile entegre etmek için gereken tüm adımları içerir.

---

## 📝 ÖNEMLİ BİLGİLER

- **Android Paket Adı**: `com.example.eka_app`
- **iOS Bundle ID**: `com.example.ekaApp`
- **Minimum Android SDK**: 21
- **Minimum iOS Version**: 12.0

---

## AŞAMA 1: Firebase Projesi Oluşturma

### 1.1 Firebase Console'a Giriş
1. https://console.firebase.google.com adresine gidin
2. Google hesabınızla giriş yapın

### 1.2 Yeni Proje Oluşturma
1. **"Proje ekle"** (Add project) butonuna tıklayın
2. Proje adı girin: **`eka-app`** (veya istediğiniz bir isim)
3. **"Devam et"** butonuna tıklayın
4. **Google Analytics**:
   - ✅ **Önerilen**: Etkinleştirin (gelecekte faydalı olacak)
   - ⚠️ İstemiyorsanız kapatabilirsiniz
5. **"Proje oluştur"** butonuna tıklayın
6. Proje oluşturulduktan sonra **"Devam et"** butonuna tıklayın

---

## AŞAMA 2: Firebase CLI Kurulumu

### 2.1 Node.js Kontrolü
Terminal'de kontrol edin:
```bash
node --version
```

Eğer Node.js yüklü değilse: https://nodejs.org/en/download/ adresinden indirin

### 2.2 Firebase CLI'yi Kurun
```bash
npm install -g firebase-tools
```

### 2.3 Firebase'e Giriş Yapın
```bash
firebase login
```
- Tarayıcı açılacak, Google hesabınızla giriş yapın
- İzinleri onaylayın
- "Firebase CLI Login Successful" mesajını görmelisiniz

### 2.4 FlutterFire CLI'yi Kurun
```bash
dart pub global activate flutterfire_cli
```

### 2.5 FlutterFire Configure Komutunu Çalıştırın
```bash
flutterfire configure
```

Bu komut:
- ✅ Firebase projenizi otomatik seçer/oluşturur
- ✅ Android ve iOS platformlarını otomatik yapılandırır
- ✅ `lib/firebase_options.dart` dosyasını otomatik günceller
- ✅ `google-services.json` (Android) dosyasını indirir
- ✅ `GoogleService-Info.plist` (iOS) dosyasını indirir

**Sorular:**
- "Which Firebase project?" → Oluşturduğunuz projeyi seçin
- "Which platforms?" → `android` ve `ios` seçin (space ile işaretleyin)

---

## AŞAMA 3: Firebase Authentication Etkinleştirme

### 3.1 Authentication Servisini Açın
1. Firebase Console'da sol menüden **"Authentication"** seçin
2. **"Başla"** (Get started) butonuna tıklayın

### 3.2 E-posta/Şifre Girişini Etkinleştirin
1. **"Sign-in method"** sekmesine gidin
2. **"E-posta/Şifre"** (Email/Password) satırına tıklayın
3. **İlk seçeneği (Email/Password)** etkinleştirin ✅
4. İkinci seçeneği (Email link) kapalı bırakabilirsiniz
5. **"Kaydet"** butonuna tıklayın

✅ **Başarılı!** E-posta/Şifre girişi artık aktif

---

## AŞAMA 4: Cloud Firestore Veritabanı Kurulumu

### 4.1 Firestore'u Başlatın
1. Sol menüden **"Firestore Database"** seçin
2. **"Veritabanı oluştur"** (Create database) butonuna tıklayın

### 4.2 Güvenlik Kurallarını Seçin
**Geliştirme için:**
- ✅ **"Test modunda başlat"** (Start in test mode) seçin
- Bu mod 30 gün boyunca herkese okuma/yazma izni verir
- ⚠️ **Önemli**: Canlıya alırken güvenlik kurallarını güncelleyin!

**Veya Production için:**
- **"Üretim modunda başlat"** (Start in production mode)
- Güvenlik kurallarını manuel yapılandırmanız gerekecek

### 4.3 Konum Seçimi
- Türkiye için en yakın: **`europe-west1`** (Belçika)
- Veya **`europe-west3`** (Frankfurt)
- **"Etkinleştir"** butonuna tıklayın

### 4.4 Güvenlik Kurallarını Güncelleyin (Önerilen)

Firestore > Rules sekmesine gidin ve şu kuralları yapıştırın:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Kullanıcılar koleksiyonu
    match /users/{userId} {
      // Kullanıcı sadece kendi verisini okuyabilir
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Kullanıcı kendi verisini güncelleyebilir (ama rol değiştiremez)
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.data.role == resource.data.role;
      
      // Sadece admin kullanıcılar diğer kullanıcıları görebilir
      allow read: if request.auth != null && 
                    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Yeni kullanıcı oluşturma (kayıt için)
      allow create: if request.auth != null;
    }
    
    // Görevler koleksiyonu (gelecek aşamalar için)
    match /tasks/{taskId} {
      // Admin tüm görevleri görebilir ve yönetebilir
      allow read, write: if request.auth != null && 
                           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Sürücüler sadece kendilerine atanan görevleri görebilir
      allow read: if request.auth != null && 
                    resource.data.driverId == request.auth.uid;
      
      // Sürücüler görev durumunu güncelleyebilir
      allow update: if request.auth != null && 
                      resource.data.driverId == request.auth.uid;
    }
  }
}
```

**"Yayınla"** (Publish) butonuna tıklayın.

---

## AŞAMA 5: Test Kullanıcıları Oluşturma

### 5.1 Yönetici Kullanıcısı Oluşturma

#### Authentication'da Kullanıcı Ekleyin:
1. **Authentication** > **Users** sekmesine gidin
2. **"Kullanıcı ekle"** (Add user) butonuna tıklayın
3. **E-posta**: `admin@eka.com`
4. **Şifre**: `admin123456` (en az 6 karakter)
5. **"Kullanıcı ekle"** butonuna tıklayın
6. **Kullanıcı ID'sini kopyalayın** (örn: `abc123xyz...`)

#### Firestore'da Kullanıcı Verisi Ekleyin:
1. **Firestore Database** sayfasına gidin
2. **"Koleksiyon başlat"** (Start collection) butonuna tıklayın
3. **Koleksiyon ID**: `users`
4. **İleri** butonuna tıklayın
5. **Belge ID**: Kopyaladığınız kullanıcı ID'sini yapıştırın
6. **Alanları ekleyin**:

| Alan | Tür | Değer |
|------|-----|-------|
| `email` | string | `admin@eka.com` |
| `name` | string | `Admin Kullanıcı` |
| `role` | string | `admin` |
| `createdAt` | timestamp | (şimdi) |
| `updatedAt` | null | |
| `assignedDriverId` | null | |

7. **"Kaydet"** butonuna tıklayın

### 5.2 Sürücü Kullanıcısı Oluşturma

#### Authentication'da Kullanıcı Ekleyin:
1. **Authentication** > **Users** sekmesi > **"Kullanıcı ekle"**
2. **E-posta**: `driver@eka.com`
3. **Şifre**: `driver123456`
4. **"Kullanıcı ekle"** butonuna tıklayın
5. **Kullanıcı ID'sini kopyalayın**

#### Firestore'da Kullanıcı Verisi Ekleyin:
1. **Firestore Database** > **users** koleksiyonu
2. **"Belge ekle"** (Add document) butonuna tıklayın
3. **Belge ID**: Kopyaladığınız kullanıcı ID'sini yapıştırın
4. **Alanları ekleyin**:

| Alan | Tür | Değer |
|------|-----|-------|
| `email` | string | `driver@eka.com` |
| `name` | string | `Sürücü 1` |
| `role` | string | `driver` |
| `createdAt` | timestamp | (şimdi) |
| `updatedAt` | null | |
| `assignedDriverId` | null | |

5. **"Kaydet"** butonuna tıklayın

---

## AŞAMA 6: Dosya Kontrolü

FlutterFire configure komutunu çalıştırdıktan sonra bu dosyaların oluşturulduğundan emin olun:

### ✅ Kontrol Listesi:

**Android:**
- [ ] `android/app/google-services.json` dosyası var mı?

**iOS:**
- [ ] `ios/Runner/GoogleService-Info.plist` dosyası var mı?

**Flutter:**
- [ ] `lib/firebase_options.dart` dosyası güncellenmiş mi?
- [ ] Dosyada gerçek API key'ler var mı? (YOUR_API_KEY değil)

---

## AŞAMA 7: Uygulamayı Test Etme

### 7.1 Bağımlılıkları Yükleyin
```bash
flutter pub get
```

### 7.2 Uygulamayı Çalıştırın
```bash
flutter run
```

### 7.3 Giriş Yapın
**Yönetici olarak:**
- E-posta: `admin@eka.com`
- Şifre: `admin123456`

**Sürücü olarak:**
- E-posta: `driver@eka.com`
- Şifre: `driver123456`

---

## 🔧 Sorun Giderme

### Hata: "Firebase not configured"
**Çözüm:**
```bash
flutterfire configure
```
Komutu tekrar çalıştırın ve projenizi seçin.

### Hata: "Null check operator used on a null value"
**Çözüm:**
- Firestore'da kullanıcı verisi oluşturulmuş mu kontrol edin
- Authentication'daki kullanıcı ID ile Firestore'daki belge ID'si aynı mı?

### Hata: "PERMISSION_DENIED"
**Çözüm:**
- Firestore güvenlik kurallarını kontrol edin
- Test modunda mısınız?
- Kurallar yayınlanmış mı?

### Android Build Hatası
**Çözüm:**
```bash
flutter clean
flutter pub get
flutter run
```

### iOS Build Hatası (macOS)
**Çözüm:**
```bash
cd ios
pod install
cd ..
flutter run
```

---

## 📊 Firebase Console Genel Bakış

Kurulum tamamlandıktan sonra Firebase Console'da şu bölümleri göreceksiniz:

1. **🏠 Project Overview**: Genel bakış ve ayarlar
2. **👤 Authentication**: Kullanıcı yönetimi (2 kullanıcı olmalı)
3. **🗄️ Firestore Database**: Veritabanı (users koleksiyonu olmalı)
4. **📊 Analytics** (opsiyonel): Kullanım istatistikleri
5. **⚙️ Project Settings**: Proje yapılandırması

---

## ✅ Kurulum Başarılı!

Eğer:
- ✅ Giriş yapabiliyorsanız
- ✅ Yönetici ve Sürücü panelleri açılıyorsa
- ✅ Çıkış yapabiliyorsanız

**Tebrikler! Firebase entegrasyonu başarılı!** 🎉

---

## 📞 Destek

Sorun yaşarsanız:
1. Hata mesajını tam olarak okuyun
2. Firebase Console > Firestore > Rules kontrol edin
3. Authentication > Users kısmında kullanıcılar var mı?
4. `google-services.json` dosyası var mı?

---

**Son Güncelleme**: Aşama 1 - Proje Kurulumu ve Kimlik Doğrulama

