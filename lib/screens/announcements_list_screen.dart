import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_pet/models/announcement.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AnnouncementsListScreen extends StatefulWidget {
  final List<Announcement>? announcements;

  const AnnouncementsListScreen({super.key, this.announcements});

  @override
  State<AnnouncementsListScreen> createState() =>
      _AnnouncementsListScreenState();
}

class _AnnouncementsListScreenState extends State<AnnouncementsListScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  final Map<int, bool> _favoriteStatus = {};

  @override
  void initState() {
    super.initState();
    _announcementsFuture = widget.announcements != null
        ? Future.value(widget.announcements)
        : _fetchAnnouncements();
    debugPrint(
        'AnnouncementsListScreen: Initialized with ${widget.announcements?.length ?? 0} announcements');
  }

  Future<List<Announcement>> _fetchAnnouncements() async {
    try {
      final response = await ApiService().searchAnnouncements();
      if (response == null) {
        debugPrint(
            'AnnouncementsListScreen: No announcements found (null response)');
        return [];
      }
      final announcements =
          response.map((json) => Announcement.fromJson(json)).toList();
      debugPrint(
          'AnnouncementsListScreen: Fetched ${announcements.length} announcements');
      for (var announcement in announcements) {
        _favoriteStatus[announcement.id] =
            await _checkFavoriteStatus(announcement.id);
      }
      return announcements;
    } catch (e) {
      debugPrint('AnnouncementsListScreen: Error fetching announcements: $e');
      final errorMessage = e is AuthException
          ? 'Authorization required'
          : ApiService().extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
      return [];
    }
  }

  Future<bool> _checkFavoriteStatus(int announcementId) async {
    try {
      final favorites = await ApiService().getFavorites();
      return favorites.any((item) => item['id'] == announcementId);
    } catch (e) {
      debugPrint('AnnouncementsListScreen: Error checking favorite status: $e');
      return false;
    }
  }

  Future<void> _toggleFavorite(Announcement announcement) async {
    try {
      final isFavorite = _favoriteStatus[announcement.id] ?? false;
      if (isFavorite) {
        await ApiService().removeFavorite(announcement.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed from Favorites',
                style:
                    GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
              ),
            ),
          );
        }
        setState(() {
          _favoriteStatus[announcement.id] = false;
        });
      } else {
        await ApiService().addFavorite(announcement.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to Favorites',
                style:
                    GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
              ),
            ),
          );
        }
        setState(() {
          _favoriteStatus[announcement.id] = true;
        });
      }
    } catch (e) {
      debugPrint('AnnouncementsListScreen: ToggleFavorite error: $e');
      final errorMessage = e is AuthException
          ? 'Authorization required'
          : ApiService().extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage',
              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
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

  void _refreshAnnouncements() {
    setState(() {
      _announcementsFuture = _fetchAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Announcements',
          style: GoogleFonts.lakkiReddy(
            fontSize: 24,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF7D6199)),
            onPressed: () {
              debugPrint('AnnouncementsListScreen: Navigating to search');
              Navigator.pushNamed(context, '/search_announcements');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF7D6199)));
          }
          if (snapshot.hasError) {
            debugPrint('AnnouncementsListScreen: Error: ${snapshot.error}');
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.lakkiReddy(
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No announcements found',
                style: GoogleFonts.lakkiReddy(
                  fontSize: 20,
                  color: const Color(0xFF7D6199),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final announcements = snapshot.data!;
          debugPrint(
              'AnnouncementsListScreen: Rendering ${announcements.length} announcements');

// Создаём список виджетов для CardSwiper
          final List<Widget> cards = announcements.map((announcement) {
            final isFavorite = _favoriteStatus[announcement.id] ?? false;
            return GestureDetector(
              onTap: () async {
                debugPrint(
                    'AnnouncementsListScreen: Navigating to announcement detail: ${announcement.id}');
                final result = await Navigator.pushNamed(
                  context,
                  '/announcement_detail',
                  arguments: announcement,
                );
                if (result is Announcement || result is int) {
                  _refreshAnnouncements();
                }
              },
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFFFFFBF2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (announcement.imagePaths.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: announcement.imagePaths[0],
                          height: 300,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF7D6199)),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error,
                            size: 100,
                            color: Color(0xFF7D6199),
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.pets,
                        size: 100,
                        color: Color(0xFF7D6199),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  announcement.pet.name ?? 'No name',
                                  style: GoogleFonts.lakkiReddy(
                                    fontSize: 24,
                                    color: const Color(0xFF7D6199),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.red
                                      : const Color(0xFF7D6199),
                                ),
                                onPressed: () => _toggleFavorite(announcement),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Breed: ${announcement.pet.breed ?? "Not specified"}',
                            style: GoogleFonts.oldenburg(
                              fontSize: 16,
                              color: const Color(0xFF7D6199),
                            ),
                          ),
                          Text(
                            'Date: ${announcement.timestamp.isNotEmpty ? DateFormat('dd.MM.yyyy').format(DateTime.parse(announcement.timestamp)) : "Not specified"}',
                            style: GoogleFonts.oldenburg(
                              fontSize: 16,
                              color: const Color(0xFF7D6199),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/announcement_detail',
                                arguments: announcement,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF8E8),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Details',
                              style: GoogleFonts.oldenburg(
                                fontSize: 20,
                                color: const Color(0xFF7D6199),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return CardSwiper(
            cards: cards,
            direction: CardSwiperDirection.right,
            isHorizontalSwipingEnabled: true,
            padding: const EdgeInsets.all(16.0),
            onSwipe: (index, direction) {
              debugPrint(
                  'AnnouncementsListScreen: Swiped card $index to $direction');
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          debugPrint(
              'AnnouncementsListScreen: Navigating to create announcement');
          final result =
              await Navigator.pushNamed(context, '/create_announcement');
          if (result is Announcement) {
            _refreshAnnouncements();
          }
        },
        backgroundColor: const Color(0xFFFFF8E8),
        child: const Icon(Icons.add, color: Color(0xFF7D6199)),
      ),
    );
  }
}
