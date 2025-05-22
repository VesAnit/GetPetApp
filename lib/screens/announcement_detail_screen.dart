import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_pet/models/announcement.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:get_pet/screens/create_announcement_screen.dart';
import 'package:get_pet/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:get_pet/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_pet/utils/string_extensions.dart';
import 'dart:convert';

class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({super.key});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  bool _isLoading = true;
  bool _isFavorite = false;
  Announcement? announcement;
  String? errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint('AnnouncementDetailScreen: Route arguments: $args');
      if (args is! Announcement) {
        throw Exception('Invalid or null announcement data');
      }
      announcement = args;
      await _checkFavoriteStatus();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('AnnouncementDetailScreen: Error loading announcement: $e');
      final errorMessage = e is AuthException ? 'Authorization required' : _extractErrorMessage(e);
      setState(() {
        _isLoading = false;
        this.errorMessage = errorMessage;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final favorites = await ApiService().getFavorites();
      setState(() {
        _isFavorite = favorites.any((item) => item['id'] == announcement!.id);
      });
    } catch (e) {
      debugPrint('AnnouncementDetailScreen: Error checking favorite status: $e');
      final errorMessage = e is AuthException ? 'Authorization required' : _extractErrorMessage(e);
      setState(() {
        this.errorMessage = errorMessage;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final ann = announcement!;
      if (_isFavorite) {
        await ApiService().removeFavorite(ann.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed from Heart',
                style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
              ),
            ),
          );
        }
      } else {
        await ApiService().addFavorite(ann.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to Heart',
                style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
              ),
            ),
          );
        }
      }
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } catch (e) {
      debugPrint('AnnouncementDetailScreen: ToggleFavorite error: $e');
      final errorMessage = e is AuthException ? 'Authorization required' : _extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  Future<void> _deleteAnnouncement() async {
    try {
      final ann = announcement!;
      await ApiService().deleteAnnouncement(ann.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Announcement deleted',
              style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
            ),
          ),
        );
        Navigator.pop(context, ann.id);
      }
    } catch (e) {
      debugPrint('AnnouncementDetailScreen: Delete error: $e');
      final errorMessage = e is AuthException ? 'Authorization required' : _extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.oldenburg(fontSize: 20, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  String _extractErrorMessage(dynamic error) {
    try {
      final errorString = error.toString().replaceFirst('Exception: ', '');
      try {
        final errorJson = jsonDecode(errorString);
        if (errorJson is Map<String, dynamic>) {
          final detail = errorJson['detail'];
          if (detail is Map<String, dynamic>) {
            return detail['message']?.toString() ?? 'An error occurred';
          }
          return detail?.toString() ?? 'An error occurred';
        }
        return errorString;
      } catch (_) {
        return errorString;
      }
    } catch (_) {
      return 'An error occurred';
    }
  }

  List<String> _formatKeywords(String? keywords) {
    if (keywords == null || keywords.isEmpty) return ['None'];
    return keywords.split(',').map((keyword) {
      keyword = keyword.trim().replaceAll('_', ' ');
      final words = <String>[];
      var currentWord = '';
      for (var i = 0; i < keyword.length; i++) {
        final char = keyword[i];
        if (char == char.toUpperCase() && currentWord.isNotEmpty) {
          words.add(currentWord.toLowerCase());
          currentWord = char;
        } else {
          currentWord += char;
        }
      }
      if (currentWord.isNotEmpty) {
        words.add(currentWord.toLowerCase());
      }
      return words.join(' ').capitalize();
    }).toList();
  }

  Widget _buildKeywordChips() {
    final keywords = _formatKeywords(announcement?.keywords);
    if (keywords.contains('None')) {
      return Text(
        'None',
        style: GoogleFonts.oldenburg(
          fontSize: 18,
          color: const Color(0xFF7D6199),
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: keywords.map((keyword) {
        return Chip(
          label: Text(
            keyword,
            style: GoogleFonts.oldenburg(
              fontSize: 18,
              color: const Color(0xFF7D6199),
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFFFFBF2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildField(String label, String? value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Text(
          label,
          style: GoogleFonts.oldenburg(
            fontSize: 14,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value ?? 'Not specified',
          style: GoogleFonts.oldenburg(
            fontSize: 18,
            color: const Color(0xFF4A2C5A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.userId != null &&
        announcement != null &&
        announcement!.userId == int.tryParse(authProvider.userId!);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE4E1),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7D6199))),
      );
    }

    if (announcement == null || errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFE4E1),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Error',
            style: GoogleFonts.oldenburg(
              fontSize: 24,
              color: const Color(0xFF7D6199),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            errorMessage ?? 'Announcement not found',
            style: GoogleFonts.oldenburg(
              fontSize: 20,
              color: const Color(0xFF7D6199),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final ann = announcement!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pet Details',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : const Color(0xFF7D6199),
            ),
            onPressed: _toggleFavorite,
          ),
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF7D6199)),
              onPressed: () async {
                debugPrint('AnnouncementDetailScreen: Navigating to edit announcement: ${ann.id}');
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateAnnouncementScreen(
                      announcement: ann,
                      isEditMode: true,
                    ),
                  ),
                );
                if (result is Announcement && mounted) {
                  setState(() {
                    announcement = result;
                  });
                  await _checkFavoriteStatus();
                  Navigator.pop(context, result);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFFFFFBF2),
                    title: Text(
                      'Delete announcement?',
                      style: GoogleFonts.oldenburg(
                        fontSize: 24,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.oldenburg(
                        fontSize: 20,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.lakkiReddy(
                            fontSize: 18,
                            color: const Color(0xFF7D6199),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteAnnouncement();
                        },
                        child: Text(
                          'Delete',
                          style: GoogleFonts.oldenburg(
                            fontSize: 18,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ann.imagePaths.isNotEmpty)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ann.imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: ann.imagePaths[index],
                          width: MediaQuery.sizeOf(context).width * 0.7,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(
                            color: Color(0xFF7D6199),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error,
                            color: Color(0xFF7D6199),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const Icon(
                Icons.pets,
                size: 100,
                color: Color(0xFF7D6199),
              ),
            const SizedBox(height: 10),
            Text(
              ann.pet.name ?? 'No name',
              style: GoogleFonts.oldenburg(
                fontSize: 26,
                color: const Color(0xFF7D6199),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildField('Type', ann.pet.animalType.capitalize()),
            _buildField('Breed', ann.pet.breed),
            _buildField('Gender', ann.pet.gender),
            _buildField('Age', ann.pet.age != null ? '${ann.pet.age} years' : null),
            _buildField('Color', ann.pet.color),
            _buildField('Location', ann.location),
            _buildField(
              'Date of Announcement',
              ann.timestamp.isNotEmpty
                  ? DateFormat('dd.MM.yyyy').format(DateTime.parse(ann.timestamp))
                  : 'Not specified',
            ),
            _buildField('Author', ann.user?.username),
            const SizedBox(height: 20),
            Text(
              'Description:',
              style: GoogleFonts.oldenburg(
                fontSize: 14,
                color: const Color(0xFF7D6199),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                ann.description ?? 'No description',
                style: GoogleFonts.oldenburg(
                  fontSize: 18,
                  color: const Color(0xFF8A7A9A),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Keywords:',
              style: GoogleFonts.oldenburg(
                fontSize: 14,
                color: const Color(0xFF7D6199),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildKeywordChips(),
            const SizedBox(height: 20),
            if (!isOwner)
              ElevatedButton(
                onPressed: () {
                  debugPrint('AnnouncementDetailScreen: Navigating to chat for announcement: ${ann.id}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(announcementId: ann.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF8E8),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Chat',
                  style: GoogleFonts.lakkiReddy(
                    fontSize: 22,
                    color: const Color(0xFF7D6199),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
