import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_pet/utils/string_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:get_pet/models/announcement.dart';
import 'package:http/http.dart' as http;

class CreateAnnouncementScreen extends StatefulWidget {
  final Announcement? announcement;
  final bool isEditMode;

  const CreateAnnouncementScreen({
    super.key,
    this.announcement,
    this.isEditMode = false,
  });

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _animalType;
  String? _gender;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _breedController;
  late TextEditingController _colorController;
  String? _keywords;
  String? _description;
  String? _location;
  List<File> _images = [];
  bool _animalTypeLocked = false;
  String? _suggestedAnimalType;
  String? _suggestedBreed;
  double _suggestedBreedConfidence = 0.0;
  final Set<String> _selectedKeywords = {};
  String? _error;
  bool _isLoading = false;
  late TextEditingController _locationController;
  late FocusNode _locationFocusNode;
  Announcement? _loadedAnnouncement;
  bool _isInitialized = false;
  final List<String> _availableKeywords = [
    'vaccinated',
    'neutered',
    'friendly',
    'good with kids',
    'good with cats',
    'good with dogs',
    'not good with cats',
    'not good with dogs',
    'needs trainer',
    'not vaccinated',
    'not neutered',
    'playful',
    'active',
    'calm',
    'low energy',
    'protective',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _breedController = TextEditingController();
    _colorController = TextEditingController();
    _locationController = TextEditingController();
    _locationFocusNode = FocusNode();
    debugPrint('CreateAnnouncementScreen: GOOGLE_PLACES_API_KEY=${dotenv.env['GOOGLE_PLACES_API_KEY']}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeScreen();
      _isInitialized = true;
    }
  }

  Future<void> _initializeScreen() async {
    Announcement? announcement = widget.announcement;
    if (announcement == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('announcement')) {
        announcement = args['announcement'] as Announcement?;
      }
    }

    debugPrint('CreateAnnouncementScreen: Initializing with announcement: ${announcement?.id}, isEditMode: ${widget.isEditMode}');

    if (widget.isEditMode && announcement != null) {
      setState(() {
        _isLoading = true;
        _loadedAnnouncement = announcement;
      });
      await _initializeEditMode(announcement);
    } else if (widget.isEditMode && announcement == null) {
      setState(() {
        _error = 'Announcement data is missing';
        _isLoading = false;
      });
      debugPrint('CreateAnnouncementScreen: Error - announcement is null in edit mode');
    } else {
      debugPrint('CreateAnnouncementScreen: Initialized in create mode');
    }
  }

  Future<void> _initializeEditMode(Announcement announcement) async {
    debugPrint('CreateAnnouncementScreen: Initializing edit mode with announcement: ${announcement.id}, pet: ${announcement.pet.toString()}, images: ${announcement.imagePaths}');

    setState(() {
      _animalType = announcement.pet.animalType.capitalize();
      _gender = announcement.pet.gender;
      _nameController.text = announcement.pet.name ?? '';
      _ageController.text = announcement.pet.age?.toString() ?? '';
      _breedController.text = announcement.pet.breed ?? '';
      _colorController.text = announcement.pet.color ?? '';
      _keywords = announcement.keywords;
      _description = announcement.description;
      _locationController.text = announcement.location ?? '';
      _location = announcement.location;
      _suggestedAnimalType = announcement.pet.animalType;
      _suggestedBreed = announcement.pet.breed;
      _animalTypeLocked = true;
      if (announcement.keywords != null) {
        _selectedKeywords.addAll(announcement.keywords!.split(',').map((k) => k.trim().replaceAll('_', ' ')));
      }
    });

    for (var imagePath in announcement.imagePaths) {
      try {
        debugPrint('CreateAnnouncementScreen: Attempting to load image: $imagePath');
        final response = await http.get(Uri.parse(imagePath));
        if (response.statusCode == 200) {
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/${imagePath.split('/').last}');
          await tempFile.writeAsBytes(response.bodyBytes);
          setState(() {
            _images.add(tempFile);
          });
          debugPrint('CreateAnnouncementScreen: Loaded image: ${tempFile.path}');
        } else {
          debugPrint('CreateAnnouncementScreen: Failed to load image $imagePath, status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('CreateAnnouncementScreen: Error loading image $imagePath: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
    debugPrint('CreateAnnouncementScreen: Edit mode initialized, images loaded: ${_images.length}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    debugPrint('CreateAnnouncementScreen: Picking images');
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) {
      debugPrint('CreateAnnouncementScreen: No images selected');
      return;
    }

    for (var file in pickedFiles) {
      if (_images.length >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum 3 images',
                style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('CreateAnnouncementScreen: Max 3 images reached');
        break;
      }
      final image = File(file.path);
      final isValid = await _validateSingleImage(image);
      if (isValid && mounted) {
        setState(() {
          _images.add(image);
          debugPrint('CreateAnnouncementScreen: Added image: ${image.path}');
        });
      }
    }
  }

  Future<bool> _validateSingleImage(File image) async {
    try {
      final response = await ApiService().validateImages(
        image: image,
        previousType: _suggestedAnimalType,
      );
      debugPrint('CreateAnnouncementScreen: Validate image response: $response');
      if (mounted) {
        setState(() {
          _suggestedAnimalType = response['suggested_animal_type'];
          if (_suggestedAnimalType != null) {
            _animalType = _suggestedAnimalType == 'dog' ? 'Dog' : 'Cat';
            _animalTypeLocked = true;
          }
          if (response['max_confidence_breed'] != null) {
            final newConfidence = response['confidence'].toDouble();
            if (_suggestedBreed == null || newConfidence > _suggestedBreedConfidence) {
              _suggestedBreed = response['max_confidence_breed'];
              _suggestedBreedConfidence = newConfidence;
              _breedController.text = _suggestedBreed != null
                  ? _suggestedBreed!.replaceAll('_', ' ').toLowerCase().capitalize()
                  : '';
            }
          }
          _error = null;
        });
      }
      return true;
    } catch (e) {
      debugPrint('CreateAnnouncementScreen: Image validation error: $e');
      final errorMessage = ApiService().extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _error = errorMessage;
        });
      }
      return false;
    }
  }

  Future<void> _removeImage(int index) async {
    debugPrint('CreateAnnouncementScreen: Removing image at index $index');
    setState(() {
      _images.removeAt(index);
    });
    if (_images.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestedAnimalType = null;
          _suggestedBreed = null;
          _suggestedBreedConfidence = 0.0;
          _animalType = null;
          _breedController.clear();
          _animalTypeLocked = false;
          _error = null;
        });
      }
      debugPrint('CreateAnnouncementScreen: No images left, cleared suggestions');
      return;
    }
    String? newSuggestedAnimalType;
    String? newSuggestedBreed;
    double newConfidence = 0.0;
    for (var image in _images) {
      try {
        final response = await ApiService().validateImages(
          image: image,
          previousType: newSuggestedAnimalType,
        );
        if (response['suggested_animal_type'] != null) {
          newSuggestedAnimalType = response['suggested_animal_type'];
        }
        if (response['max_confidence_breed'] != null && response['confidence'] > newConfidence) {
          newSuggestedBreed = response['max_confidence_breed'];
          newConfidence = response['confidence'].toDouble();
        }
      } catch (e) {
        debugPrint('CreateAnnouncementScreen: Error revalidating image: $e');
      }
    }
    if (mounted) {
      setState(() {
        _suggestedAnimalType = newSuggestedAnimalType;
        _suggestedBreed = newSuggestedBreed;
        _suggestedBreedConfidence = newConfidence;
        if (_suggestedAnimalType != null) {
          _animalType = _suggestedAnimalType == 'dog' ? 'Dog' : 'Cat';
          _animalTypeLocked = true;
        } else {
          _animalType = null;
          _animalTypeLocked = false;
        }
        _breedController.text = newSuggestedBreed != null
            ? newSuggestedBreed.replaceAll('_', ' ').toLowerCase().capitalize()
            : '';
        _error = null;
      });
    }
    debugPrint('CreateAnnouncementScreen: Updated suggestions after image removal');
  }

  Future<void> _submit() async {
    debugPrint('CreateAnnouncementScreen: Submitting announcement, location: ${_locationController.text}, name: ${_nameController.text}');
    if (!_formKey.currentState!.validate()) {
      debugPrint('CreateAnnouncementScreen: Form validation failed');
      return;
    }
    if (_images.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Please add at least one image';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please add at least one image',
              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('CreateAnnouncementScreen: No images provided');
      return;
    }

    setState(() => _isLoading = true);
    try {
      Announcement? updatedAnnouncement;
      final name = _nameController.text.isNotEmpty ? _nameController.text : null;
      final age = _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null;
      final breed = _breedController.text.isNotEmpty ? _breedController.text : null;
      final color = _colorController.text.isNotEmpty ? _colorController.text : null;
      final description = _description?.isNotEmpty == true ? _description : null;
      final location = _locationController.text.isNotEmpty ? _locationController.text : null;

      debugPrint('CreateAnnouncementScreen: Saved name: $name, age: $age, breed: $breed, color: $color, description: $description, location: $location');

      if (widget.isEditMode && _loadedAnnouncement != null) {
        updatedAnnouncement = await ApiService().updateAnnouncement(
          announcementId: _loadedAnnouncement!.id,
          animalType: _animalType!.toLowerCase(),
          gender: _gender!,
          name: name,
          age: age,
          breed: breed,
          color: color,
          keywords: _keywords,
          description: description,
          location: location,
          images: _images,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Announcement updated successfully!',
                style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        debugPrint('CreateAnnouncementScreen: Announcement updated successfully');
      } else {
        updatedAnnouncement = await ApiService().createAnnouncement(
          animalType: _animalType!.toLowerCase(),
          gender: _gender!,
          name: name,
          age: age,
          breed: breed,
          color: color,
          keywords: _keywords,
          description: description,
          location: location,
          images: _images,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Announcement created successfully!',
                style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        debugPrint('CreateAnnouncementScreen: Announcement created successfully');
      }
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context, updatedAnnouncement);
      }
    } catch (e) {
      final errorMessage = e is AuthException ? 'Authorization required' : ApiService().extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
        if (e is AuthException) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
      debugPrint('CreateAnnouncementScreen: Error ${widget.isEditMode ? 'updating' : 'creating'} announcement: $e');
    }
  }

  Widget _buildLocationField() {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    debugPrint('CreateAnnouncementScreen: Using GOOGLE_PLACES_API_KEY=$apiKey');
    return GooglePlaceAutoCompleteTextField(
      textEditingController: _locationController,
      googleAPIKey: apiKey,
      focusNode: _locationFocusNode,
      textStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
      inputDecoration: InputDecoration(
        labelText: 'Location',
        border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
        labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
        filled: true,
        fillColor: const Color(0xFFFFFBF2),
      ),
      debounceTime: 800,
      isLatLngRequired: false,
      countries: [],
      language: 'en',
      getPlaceDetailWithLatLng: (Prediction prediction) {
        debugPrint('CreateAnnouncementScreen: Selected place: ${prediction.description}');
        _locationController.text = prediction.description ?? '';
        _location = prediction.description;
      },
      itemClick: (Prediction prediction) {
        debugPrint('CreateAnnouncementScreen: Item clicked: ${prediction.description}');
        _locationController.text = prediction.description ?? '';
        _location = prediction.description;
        _locationController.selection = TextSelection.fromPosition(
          TextPosition(offset: _locationController.text.length),
        );
        _locationFocusNode.requestFocus();
      },
      itemBuilder: (context, index, Prediction prediction) {
        return Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFF2A03D)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  prediction.description ?? '',
                  style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
                ),
              ),
            ],
          ),
        );
      },
      seperatedBuilder: const Divider(),
      isCrossBtnShown: true,
    );
  }

  Widget _buildImageContainer(int index) {
    if (index < _images.length) {
      return Stack(
        children: [
          Image.file(
            _images[index],
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('CreateAnnouncementScreen: Image file error: ${_images[index].path}, error: $error');
              return const Icon(Icons.error, size: 100, color: Color(0xFF7D6199));
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeImage(index),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF2A03D)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, size: 40, color: Color(0xFFF2A03D)),
      ),
    );
  }

  Widget _buildKeywordChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedKeywords.length >= 5 ? Colors.grey.withOpacity(0.3) : const Color(0xFFFFFBF2),
            side: BorderSide(color: _selectedKeywords.length >= 5 ? Colors.grey : const Color(0xFFF2A03D)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _selectedKeywords.length >= 5
              ? () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Maximum 5 keywords allowed!',
                          style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              : () => _showKeywordDialog(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Keywords',
                style: GoogleFonts.oldenburg(
                  fontSize: 18,
                  color: _selectedKeywords.length >= 5 ? Colors.grey : const Color(0xFF7D6199),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_drop_down,
                color: _selectedKeywords.length >= 5 ? Colors.grey : const Color(0xFF7D6199),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: _selectedKeywords.map((keyword) {
            return Chip(
              label: Text(
                keyword,
                style: GoogleFonts.oldenburg(fontSize: 16, color: const Color(0xFF7D6199)),
              ),
              backgroundColor: const Color(0xFFFFFBF2),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFF2A03D)),
                borderRadius: BorderRadius.circular(16),
              ),
              deleteIcon: const Icon(Icons.close, color: Color(0xFF7D6199), size: 18),
              onDeleted: () {
                setState(() {
                  _selectedKeywords.remove(keyword);
                  _keywords = _selectedKeywords.isEmpty
                      ? null
                      : _selectedKeywords.map((k) => k.replaceAll(' ', '_').toLowerCase()).join(',');
                });
                debugPrint('CreateAnnouncementScreen: Removed keyword: $keyword');
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showKeywordDialog() {
    final tempSelectedKeywords = Set<String>.from(_selectedKeywords);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFBF2),
          title: Text(
            'Select Keywords (max 5)',
            style: GoogleFonts.lakkiReddy(fontSize: 22, color: const Color(0xFF7D6199), fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _availableKeywords.map((keyword) {
                      return CheckboxListTile(
                        title: Text(
                          keyword,
                          style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
                        ),
                        value: tempSelectedKeywords.contains(keyword),
                        activeColor: const Color(0xFFF2A03D),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              if (tempSelectedKeywords.length < 5) {
                                tempSelectedKeywords.add(keyword);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Maximum 5 keywords allowed!',
                                      style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              tempSelectedKeywords.remove(keyword);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.lakkiReddy(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedKeywords.clear();
                  _selectedKeywords.addAll(tempSelectedKeywords);
                  _keywords = _selectedKeywords.isEmpty
                      ? null
                      : _selectedKeywords.map((k) => k.replaceAll(' ', '_').toLowerCase()).join(',');
                });
                debugPrint('CreateAnnouncementScreen: Selected keywords: $_keywords');
                Navigator.pop(dialogContext);
              },
              child: Text(
                'OK',
                style: GoogleFonts.lakkiReddy(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFDAB9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7D6199))),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditMode ? 'Edit Announcement' : 'Create Announcement',
          style: GoogleFonts.lakkiReddy(fontSize: 24, color: const Color(0xFF7D6199), fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error!,
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Animal Type',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                value: _animalType,
                items: ['Cat', 'Dog'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199))),
                  );
                }).toList(),
                onChanged: _animalTypeLocked ? null : (value) => setState(() => _animalType = value),
                validator: (value) => value == null ? 'Select type' : null,
                onTap: _animalTypeLocked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Animal type must match the photo',
                              style: GoogleFonts.lakkiReddy(fontSize: 20, color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    : null,
                disabledHint: _animalType != null
                    ? Text(_animalType!, style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)))
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                value: _gender,
                items: ['M', 'F'].map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender, style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199))),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _gender = value),
                validator: (value) => value == null ? 'Select gender' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(
                  labelText: 'Age',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
                style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(
                  labelText: 'Breed',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: 'Color',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
              ),
              const SizedBox(height: 16),
              _buildLocationField(),
              const SizedBox(height: 16),
              Text(
                'Keywords:',
                style: GoogleFonts.lakkiReddy(fontSize: 22, color: const Color(0xFFD87A68), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildKeywordChips(),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _description,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
                  labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBF2),
                ),
                onChanged: (value) => _description = value,
                style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Add Images (up to 3):',
                style: GoogleFonts.lakkiReddy(fontSize: 22, color: const Color(0xFFD87A68), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) => _buildImageContainer(index)),
              ),
              if (_suggestedAnimalType != null || _suggestedBreed != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Suggested: ${_suggestedAnimalType != null ? _suggestedAnimalType!.capitalize() : ''}${_suggestedBreed != null ? ', ${_suggestedBreed!.replaceAll('_', ' ').toLowerCase().capitalize()}' : ''}',
                    style: GoogleFonts.lakkiReddy(fontSize: 20, color: const Color(0xFF8A9254), fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF8E8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF7D6199))
                    : Text(
                        widget.isEditMode ? 'Save Changes' : 'Create',
                        style: GoogleFonts.lakkiReddy(fontSize: 24, color: const Color(0xFF7D6199), fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
