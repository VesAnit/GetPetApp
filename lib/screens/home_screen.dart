import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  bool _hasUnreadMessages = false;

  @override
  void initState() {
    super.initState();
    _checkUnreadMessages();
  }

  Future<void> _checkUnreadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    try {
      final chats = await ApiService().getUserChats();
      setState(() {
        _hasUnreadMessages = chats.any((chat) => chat['has_unread'] == true);
      });
      debugPrint('HomeScreen: Unread messages check: $_hasUnreadMessages');
    } catch (e) {
      debugPrint('HomeScreen: Error checking unread messages: $e');
    }
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all fields',
            style: GoogleFonts.lakkiReddy(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await authProvider.login(username, password);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login successful',
            style: GoogleFonts.lakkiReddy(fontSize: 18, color: Colors.white),
          ),
        ),
      );
      _loginUsernameController.clear();
      _loginPasswordController.clear();
      setState(() {});
      await _checkUnreadMessages();
      debugPrint("HomeScreen: Login successful, UI updated");
    } catch (e) {
      String errorMessage = e.toString().contains('detail')
          ? e.toString().split('"detail":"')[1].split('"')[0]
          : 'An error occurred';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.lakkiReddy(fontSize: 16, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint("HomeScreen: Login error: $e");
    }
  }

  Future<void> _register(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = _registerUsernameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all fields',
            style: GoogleFonts.lakkiReddy(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await authProvider.register(username, email, password);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration and login successful',
            style: GoogleFonts.lakkiReddy(fontSize: 18, color: Colors.white),
          ),
        ),
      );
      _registerUsernameController.clear();
      _registerEmailController.clear();
      _registerPasswordController.clear();
      setState(() {});
      await _checkUnreadMessages();
      debugPrint("HomeScreen: Register successful, UI updated");
    } catch (e) {
      String errorMessage = e.toString().contains('detail')
          ? e.toString().split('"detail":"')[1].split('"')[0]
          : 'An error occurred';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.lakkiReddy(fontSize: 16, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint("HomeScreen: Register error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    debugPrint('HomeScreen: isLoggedIn = ${authProvider.isLoggedIn}');

    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (authProvider.isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF7D6199)),
              onPressed: () async {
                await authProvider.logout();
                setState(() {
                  _hasUnreadMessages = false;
                });
                debugPrint("HomeScreen: Logout successful, UI updated");
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 200,
            left: -10,
            right: 0,
            child: Transform.rotate(
              angle: 340 * 3.14159 / 180,
              child: Opacity(
                opacity: 0.05, // Увеличена прозрачность лапок с 0.2 до 0.1
                child: Image.asset(
                  'assets/images/paws.png',
                  width: MediaQuery.of(context).size.height * 0.900,
                  height: MediaQuery.of(context).size.height * 0.900,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: authProvider.isLoggedIn
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to GetPet!',
                    style: GoogleFonts.lakkiReddy(
                      fontSize: 28,
                      color: const Color(0xFF7D6199),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16), // Увеличен отступ для лучшего расположения
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/01.png',
                      width: MediaQuery.of(context).size.height * 0.315,
                      height: MediaQuery.of(context).size.height * 0.315,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('HomeScreen: Error loading logo: $error');
                        return const Icon(Icons.error, size: 100);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/create_announcement');
                      debugPrint('HomeScreen: Navigating to /create_announcement');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Post a Pet in Need',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 22,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/search_announcements');
                      debugPrint('HomeScreen: Navigating to /search_announcements');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Find a Friend',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 22,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/my_announcements');
                      debugPrint('HomeScreen: Navigating to /my_announcements');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Your Adoption Posts',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 22,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/favorites');
                      debugPrint('HomeScreen: Navigating to /favorites');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Your Heart ♡',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 22,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/messages').then((_) {
                        _checkUnreadMessages();
                      });
                      debugPrint('HomeScreen: Navigating to /messages');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Messages',
                          style: GoogleFonts.lakkiReddy(
                            fontSize: 22,
                            color: const Color(0xFF7D6199),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_hasUnreadMessages) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB8B272),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: GoogleFonts.lakkiReddy(
                      fontSize: 24,
                      color: const Color(0xFF7D6199),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _loginUsernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFFBF2),
                      labelStyle: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF7D6199)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _loginPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFFBF2),
                      labelStyle: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF7D6199)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF8E8),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'OR',
                    style: GoogleFonts.lakkiReddy(
                      fontSize: 18,
                      color: const Color(0xFF7D6199),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign Up',
                    style: GoogleFonts.lakkiReddy(
                      fontSize: 24,
                      color: const Color(0xFF7D6199),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _registerUsernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFFBF2),
                      labelStyle: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF7D6199)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _registerEmailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFFBF2),
                      labelStyle: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF7D6199)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _registerPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFFFBF2),
                      labelStyle: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF7D6199)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _register(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD8C4E6),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.lakkiReddy(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}