import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/announcement.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'dart:convert';

class MyAnnouncementsScreen extends StatefulWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  _MyAnnouncementsScreenState createState() => _MyAnnouncementsScreenState();
}

class _MyAnnouncementsScreenState extends State<MyAnnouncementsScreen> {
  bool _isLoading = true;
  List<Announcement> _announcements = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyAnnouncements();
  }

  Future<void> _fetchMyAnnouncements() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (!authProvider.isLoggedIn) {
      debugPrint("MyAnnouncementsScreen: User not logged in, redirecting to /home");
      setState(() {
        _isLoading = false;
        _error = 'Please log in';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in',
            style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    try {
      final announcements = await ApiService().getMyAnnouncements();
      debugPrint('MyAnnouncementsScreen: Loaded ${announcements.length} announcements');
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('MyAnnouncementsScreen: Error loading announcements: $e');
      final errorMessage = e is AuthException ? 'Please log in' : _extractErrorMessage(e);
      setState(() {
        _announcements = [];
        _isLoading = false;
        _error = errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      if (e is AuthException) {
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  String _extractErrorMessage(dynamic error) {
    try {
      final errorString = error.toString().replaceFirst('Exception: ', '');
      try {
        final errorJson = jsonDecode(errorString);
        if (errorJson is Map<String, dynamic>) {
          if (errorJson['detail'] is Map<String, dynamic>) {
            return errorJson['detail']['message']?.toString() ?? 'An error occurred';
          }
          return errorJson['detail']?.toString() ?? 'An error occurred';
        }
        return errorString;
      } catch (_) {
        return errorString;
      }
    } catch (e) {
      return 'An error occurred';
    }
  }

  void _updateAnnouncement(Announcement updatedAnnouncement) {
    setState(() {
      final index = _announcements.indexWhere((a) => a.id == updatedAnnouncement.id);
      if (index != -1) {
        _announcements[index] = updatedAnnouncement;
      } else {
        _announcements.add(updatedAnnouncement);
      }
    });
  }

  void _removeAnnouncement(int announcementId) {
    setState(() {
      _announcements.removeWhere((a) => a.id == announcementId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9), // Персиковый фон из CreateAnnouncementScreen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Announcements',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199), // Фиолетовый заголовок
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7D6199))) // Фиолетовый индикатор загрузки
          : _error != null
          ? Center(
        child: Text(
          _error!,
          style: GoogleFonts.oldenburg(
            fontSize: 18,
            color: Colors.red, // Красный для ошибок
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      )
          : _announcements.isEmpty
          ? Center(
        child: Text(
          'No announcements yet',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199), // Фиолетовый текст
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0), // Отступы как в CreateAnnouncementScreen
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: const Color(0xFFFFFBF2), // Кремовый фон для карточек
            child: ListTile(
              leading: announcement.imagePaths.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: announcement.imagePaths[0], // Используем первое изображение
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(
                  color: Color(0xFF7D6199), // Фиолетовый индикатор
                ),
                errorWidget: (context, url, error) {
                  debugPrint('CachedNetworkImage error: $error, url: $url');
                  return const Icon(
                    Icons.error,
                    size: 60,
                    color: Color(0xFFD87A68), // Коралловый для ошибок
                  );
                },
              )
                  : const Icon(
                Icons.pets,
                size: 60,
                color: Color(0xFFF2A03D), // Оранжевый для иконок
              ),
              title: Text(
                announcement.pet.name ?? 'No name',
                style: GoogleFonts.oldenburg(
                  fontSize: 18,
                  color: const Color(0xFF7D6199), // Фиолетовый текст
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                announcement.pet.breed ?? 'No breed',
                style: GoogleFonts.oldenburg(
                  fontSize: 16,
                  color: const Color(0xFFD87A68), // Коралловый для подзаголовка
                ),
              ),
              onTap: () async {
                debugPrint('MyAnnouncementsScreen: Navigating to announcement detail: ${announcement.id}');
                final result = await Navigator.pushNamed(
                  context,
                  '/announcement_detail',
                  arguments: announcement,
                );
                if (result is Announcement) {
                  _updateAnnouncement(result);
                } else if (result is int) {
                  _removeAnnouncement(result);
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create_announcement');
          debugPrint("MyAnnouncementsScreen: Navigating to /create_announcement");
        },
        backgroundColor: const Color(0xFF7D6199), // Фиолетовая кнопка
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}