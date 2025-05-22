import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_pet/models/announcement.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<Announcement> _announcements = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final favoriteData = await ApiService().getFavorites();
      debugPrint('FavoritesScreen: Favorite data: $favoriteData');
      final announcements = favoriteData.map((json) => Announcement.fromJson(json as Map<String, dynamic>)).toList();

      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('FavoritesScreen: Error loading favorites: $e');
      setState(() {
        _announcements = [];
        _isLoading = false;
        _error = _extractErrorMessage(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $_error',
            style: GoogleFonts.oldenburg(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
        return errorString.replaceFirst('Exception: ', '') ?? 'An error occurred';
      } catch (_) {
        return errorString.replaceFirst('Exception: ', '') ?? 'An error occurred';
      }
    } catch (e) {
      return 'An error occurred';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Your Heart',
          style: GoogleFonts.oldenburg(
            fontSize: 24,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7D6199)))
          : _error != null
          ? Center(
        child: Text(
          _error!,
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : _announcements.isEmpty
          ? Center(
        child: Text(
          'No favorite announcements',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () async {
                debugPrint('FavoritesScreen: Navigating to announcement detail: ${announcement.id}');
                final result = await Navigator.pushNamed(
                  context,
                  '/announcement_detail',
                  arguments: announcement,
                );
                if (result != null) {
                  // Обновляем список после возвращения
                  await _loadFavorites();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Изображение
                    announcement.imagePaths.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: announcement.imagePaths[0], // Используем первое изображение
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: MediaQuery.of(context).size.width * 0.4,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(
                          color: Color(0xFF7D6199),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Color(0xFF7D6199),
                          size: 60,
                        ),
                      ),
                    )
                        : const Icon(
                      Icons.pets,
                      size: 80,
                      color: Color(0xFF7D6199),
                    ),
                    const SizedBox(width: 16.0),
                    // Информация о животном
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement.pet.name ?? 'No name',
                            style: GoogleFonts.oldenburg(
                              fontSize: 22,
                              color: const Color(0xFF7D6199),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            '${announcement.pet.animalType?.toUpperCase() ?? "Not specified"}, ${announcement.pet.breed ?? "Not specified"}',
                            style: GoogleFonts.oldenburg(
                              fontSize: 18,
                              color: const Color(0xFF4A2C5A),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            announcement.location ?? 'Not specified',
                            style: GoogleFonts.oldenburg(
                              fontSize: 18,
                              color: const Color(0xFF4A2C5A),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            announcement.timestamp.isNotEmpty
                                ? DateFormat('dd.MM.yyyy').format(DateTime.parse(announcement.timestamp))
                                : "Not specified",
                            style: GoogleFonts.oldenburg(
                              fontSize: 16,
                              color: const Color(0xFF4A2C5A),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}