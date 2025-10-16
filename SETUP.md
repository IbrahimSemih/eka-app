# EKA - Esnaf Kurye Asistanı Kurulum Rehberi

Bu rehber, EKA projesinin yerel ortamınızda çalıştırılması için gereken adımları içerir.

## Gereksinimler

- Flutter SDK (3.9.2 veya üzeri)
- Firebase CLI
- Dart SDK
- Android Studio veya Xcode (iOS için)
- Bir Firebase hesabı

## Kurulum Adımları

### 1. Bağımlılıkları Yükleyin

```bash
flutter pub get
```

### 2. Firebase Projesi Oluşturun

1. [Firebase Console](https://console.firebase.google.com) adresine gidin
2. "Proje ekle" butonuna tıklayın
3. Proje adını "eka-app" veya istediğiniz bir isim olarak girin
4. Google Analytics'i etkinleştirin (isteğe bağlı)
5. Projeyi oluşturun

### 3. Firebase CLI'yi Yükleyin

```bash
npm install -g firebase-tools
```

### 4. Firebase'e Giriş Yapın

```bash
firebase login
```

### 5. FlutterFire CLI'yi Yükleyin

```bash
dart pub global activate flutterfire_cli
```

### 6. Firebase Yapılandırmasını Oluşturun

```bash
flutterfire configure
```

Bu komut:
- Firebase projenizi seçmenizi ister
- iOS ve Android platformları için otomatik yapılandırma yapar
- `lib/firebase_options.dart` dosyasını otomatik olarak oluşturur ve günceller

### 7. Firebase Console'da Servisleri Etkinleştirin

#### Authentication
1. Firebase Console'da "Authentication" bölümüne gidin
2. "Başla" butonuna tıklayın
3. "Sign-in method" sekmesine gidin
4. "Email/Password"'ü etkinleştirin

#### Cloud Firestore
1. Firebase Console'da "Firestore Database" bölümüne gidin
2. "Veritabanı oluştur" butonuna tıklayın
3. "Test modunda başlat" seçeneğini seçin (geliştirme için)
4. Konum seçin (tercihen yakın bir bölge)
5. Oluştur butonuna tıklayın

#### Firestore Güvenlik Kuralları (Geliştirme için)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Kullanıcılar koleksiyonu
    match /users/{userId} {
      // Kullanıcı sadece kendi verisini okuyabilir/yazabilir
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Admin kullanıcılar tüm kullanıcıları görebilir
      allow read: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Diğer kurallar buraya eklenecek
  }
}
```

### 8. Android Yapılandırması

`android/app/build.gradle.kts` dosyasında minimum SDK versiyonunun 21 veya üzeri olduğundan emin olun:

```kotlin
minSdk = 21
```

### 9. iOS Yapılandırması (macOS kullanıcıları için)

`ios/Podfile` dosyasında platform versiyonunun 12.0 veya üzeri olduğundan emin olun:

```ruby
platform :ios, '12.0'
```

Ardından:
```bash
cd ios
pod install
cd ..
```

## Uygulamayı Çalıştırın

```bash
flutter run
```

## Test Kullanıcıları Oluşturma

Uygulama çalıştıktan sonra, Firebase Console'dan manuel olarak test kullanıcıları oluşturabilirsiniz:

### Yönetici Kullanıcısı
1. Firebase Console > Authentication > Users > "Kullanıcı ekle"
2. E-posta: `admin@eka.com`
3. Şifre: `admin123`
4. Firestore > users koleksiyonunda bu kullanıcı için bir belge oluşturun:
   ```json
   {
     "email": "admin@eka.com",
     "name": "Admin",
     "role": "admin",
     "createdAt": [şu anki zaman],
     "updatedAt": null,
     "assignedDriverId": null
   }
   ```

### Sürücü Kullanıcısı
1. Firebase Console > Authentication > Users > "Kullanıcı ekle"
2. E-posta: `driver@eka.com`
3. Şifre: `driver123`
4. Firestore > users koleksiyonunda bu kullanıcı için bir belge oluşturun:
   ```json
   {
     "email": "driver@eka.com",
     "name": "Sürücü",
     "role": "driver",
     "createdAt": [şu anki zaman],
     "updatedAt": null,
     "assignedDriverId": null
   }
   ```

## Proje Yapısı

```
lib/
├── models/              # Veri modelleri
│   └── user_model.dart
├── screens/             # UI ekranları
│   ├── auth/           # Kimlik doğrulama ekranları
│   │   └── login_screen.dart
│   ├── admin/          # Yönetici ekranları
│   │   └── admin_home_screen.dart
│   └── driver/         # Sürücü ekranları
│       └── driver_home_screen.dart
├── services/           # İş mantığı ve API servisleri
│   └── auth_service.dart
├── firebase_options.dart
└── main.dart
```

## Sorun Giderme

### "Firebase not configured" hatası
- `flutterfire configure` komutunu çalıştırdığınızdan emin olun
- `lib/firebase_options.dart` dosyasının doğru oluşturulduğunu kontrol edin

### iOS derlemesi başarısız oluyor
- `cd ios && pod install && cd ..` komutunu çalıştırın
- Xcode'un en güncel versiyonunu kullandığınızdan emin olun

### Android derlemesi başarısız oluyor
- `flutter clean` ve ardından `flutter pub get` komutlarını çalıştırın
- Android SDK'nın güncel olduğundan emin olun

## Sonraki Adımlar

✅ Aşama 1: Proje Kurulumu ve Kimlik Doğrulama Temelleri (Tamamlandı)
- Flutter proje kurulumu
- Firebase hazırlığı
- Rol bazlı giriş (Auth)
- Kullanıcı veri modeli

🔄 Aşama 2: Görev Yönetimi (Yakında)
- Görev oluşturma
- Görev atama
- Görev listeleme

🔄 Aşama 3: Rota Optimizasyonu (Yakında)
- Google Maps entegrasyonu
- Rota hesaplama
- Rota görselleştirme

## Destek

Herhangi bir sorunla karşılaşırsanız, lütfen proje yöneticisiyle iletişime geçin.

