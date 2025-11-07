import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/demo/polyline_demo_screen.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Environment variables'ı yükle (opsiyonel)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env dosyası yoksa devam et
  }

  // Firebase'i başlat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Tüm oturumları temizle
  await FirebaseAuth.instance.signOut();

  runApp(const ProviderScope(child: EkaApp()));
}

class EkaApp extends StatelessWidget {
  const EkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EKA - Esnaf Kurye Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// Kimlik doğrulama durumuna göre ekran yönlendirmesi
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        // Rol bazlı yönlendirme
        if (user.role == UserRole.admin) {
          return const AdminHomeScreen();
        } else {
          return const DriverHomeScreen();
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => const LoginScreen(),
    );
  }
}
