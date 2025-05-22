import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/create_announcement_screen.dart';
import 'screens/search_announcements_screen.dart';
import 'screens/announcements_list_screen.dart';
import 'screens/announcement_detail_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/my_announcements_screen.dart';
import 'screens/messages_screen.dart'; // Новый импорт

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Загружаем .env из папки lib
  await dotenv.load(fileName: "lib/.env");
  debugPrint('Loaded env: ${dotenv.env['GOOGLE_PLACES_API_KEY']}');
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const PetAdoptionApp(),
    ),
  );
}

class PetAdoptionApp extends StatelessWidget {
  const PetAdoptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('PetAdoptionApp: Building with routes');
    return MaterialApp(
      title: 'Pet Adoption',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/create_announcement': (context) => const CreateAnnouncementScreen(),
        '/search_announcements': (context) => const SearchAnnouncementsScreen(),
        '/announcements': (context) => const AnnouncementsListScreen(),
        '/announcement_detail': (context) => const AnnouncementDetailScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/my_announcements': (context) => const MyAnnouncementsScreen(),
        '/messages': (context) => const MessagesScreen(), // Новый маршрут
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    debugPrint('SplashScreen: Checking initial auth state');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loadToken();
      debugPrint('SplashScreen: Redirecting to /home (isLoggedIn: ${authProvider.isLoggedIn})');
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('SplashScreen: Error checking auth state: $e');
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
