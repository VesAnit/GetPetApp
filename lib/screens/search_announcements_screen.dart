
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_pet/models/announcement.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_pet/utils/string_extensions.dart';
import 'announcements_list_screen.dart';

class SearchAnnouncementsScreen extends StatefulWidget {
const SearchAnnouncementsScreen({super.key});

@override
_SearchAnnouncementsScreenState createState() => _SearchAnnouncementsScreenState();
}

class _SearchAnnouncementsScreenState extends State<SearchAnnouncementsScreen> {
final _formKey = GlobalKey<FormState>();
String? _animalType;
String? _gender;
int? _age;
List<String> _breeds = [];
String? _color;
final Set<String> _selectedKeywords = {};
List<File> _images = [];
String? _error;
String? _suggestedAnimalType;
List<String> _suggestedBreeds = [];
String? _searchStatus;
bool _isLoading = false;
final _breedController = TextEditingController();
final _colorController = TextEditingController();
final _ageController = TextEditingController();
final _locationController = TextEditingController();
final _locationFocusNode = FocusNode();

final List<String> _availableKeywords = [
'vaccinated',
'neutered',
'friendly',
'good_with_kids',
'good_with_cats',
'good_with_dogs',
'not_good_with_cats',
'not_good_with_dogs',
'needs_trainer',
'not_vaccinated',
'not_neutered',
'playful',
'active',
'calm',
'low_energy',
'protective',
];

@override
void dispose() {
_breedController.dispose();
_colorController.dispose();
_ageController.dispose();
_locationController.dispose();
_locationFocusNode.dispose();
super.dispose();
}

Future<void> _pickImages() async {
debugPrint('PickImages - Started');
final picker = ImagePicker();
if (_images.length >= 3) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Maximum 3 images'), backgroundColor: Colors.red),
);
}
debugPrint('PickImages - Maximum 3 images reached');
return;
}
final pickedFiles = await picker.pickMultiImage();
if (pickedFiles.isEmpty) {
debugPrint('PickImages - No images selected');
return;
}
debugPrint('PickImages - Picked ${pickedFiles.length} files: ${pickedFiles.map((f) => f.path).toList()}');

if (mounted) {
setState(() => _isLoading = true);
}
final validImages = <File>[];
for (var file in pickedFiles) {
if (_images.length + validImages.length >= 3) {
debugPrint('PickImages - Reached maximum of 3 images during processing');
break;
}
final imageFile = File(file.path);
debugPrint('PickImages - Validating image: ${imageFile.path}');
try {
final result = await ApiService().validateImages(image: imageFile, previousType: _suggestedAnimalType);
debugPrint('PickImages - API response for ${imageFile.path}: $result');
final suggestedAnimalType = result['suggested_animal_type'] as String?;
if (_animalType != null && suggestedAnimalType != null && _animalType!.toLowerCase() != suggestedAnimalType) {
throw Exception('Separate search is performed for dogs and cats');
}
validImages.add(imageFile);
if (mounted) {
setState(() {
final breed = result['max_confidence_breed'] as String?;
if (breed != null && !_suggestedBreeds.contains(breed)) {
_suggestedBreeds.add(breed);
}
_suggestedAnimalType = suggestedAnimalType;
if (_suggestedBreeds.isNotEmpty) {
for (var breed in _suggestedBreeds) {
final formattedBreed = breed.replaceAll('_', ' ').toLowerCase().capitalize();
if (!_breeds.contains(formattedBreed) && _breeds.length < 3) {
_breeds.add(formattedBreed);
}
}
_breedController.text = _breeds.join(', ');
}
if (_suggestedAnimalType != null && _animalType == null) {
_animalType = _suggestedAnimalType == 'dog' ? 'Dog' : 'Cat';
}
_error = null;
});
}
debugPrint('PickImages - Image validated: ${imageFile.path}, Suggested breeds: $_suggestedBreeds, Suggested animal type: $_suggestedAnimalType, '
'Current breeds: $_breeds, Current animal type: $_animalType');
} catch (e) {
debugPrint('PickImages - Validation error for ${imageFile.path}: $e');
final errorMessage = ApiService().extractErrorMessage(e);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(errorMessage, style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white)),
backgroundColor: Colors.red,
),
);
}
}
}
if (validImages.isNotEmpty && mounted) {
setState(() {
_images.addAll(validImages);
debugPrint('PickImages - Added valid images: ${validImages.map((img) => img.path).toList()}');
});
} else {
debugPrint('PickImages - No valid images added');
}
if (mounted) {
setState(() => _isLoading = false);
}
debugPrint('PickImages - Finished');
}

Future<void> _removeImage(int index) async {
debugPrint('RemoveImage - Removing image at index $index');
if (mounted) {
setState(() {
_images.removeAt(index);
});
}
await _updateBreedsFromImages();
}

Future<void> _updateBreedsFromImages() async {
debugPrint('UpdateBreedsFromImages - Started with ${_images.length} images');
if (_images.isEmpty) {
if (mounted) {
setState(() {
_suggestedBreeds = [];
_suggestedAnimalType = null;
_breeds = [];
_animalType = null;
_breedController.text = '';
});
}
debugPrint('UpdateBreedsFromImages - No images, cleared breeds and animal type');
return;
}
if (mounted) {
setState(() {
_isLoading = true;
_error = null;
});
}
try {
String? newSuggestedAnimalType;
final newSuggestedBreeds = <String>[];
for (var image in _images) {
final result = await ApiService().validateImages(image: image, previousType: newSuggestedAnimalType);
debugPrint('UpdateBreedsFromImages - API response: $result');
if (result['suggested_animal_type'] != null) {
newSuggestedAnimalType = result['suggested_animal_type'];
}
final breed = result['max_confidence_breed'] as String?;
if (breed != null && !newSuggestedBreeds.contains(breed)) {
newSuggestedBreeds.add(breed);
}
}
if (mounted) {
setState(() {
_suggestedBreeds = newSuggestedBreeds;
_suggestedAnimalType = newSuggestedAnimalType;
if (_suggestedBreeds.isNotEmpty) {
_breeds = _suggestedBreeds
    .map((b) => b.replaceAll('_', ' ').toLowerCase().capitalize())
    .take(3)
    .toList();
_breedController.text = _breeds.join(', ');
}
if (_suggestedAnimalType != null && _animalType == null) {
_animalType = _suggestedAnimalType == 'dog' ? 'Dog' : 'Cat';
}
});
}
debugPrint('UpdateBreedsFromImages - Suggested breeds: $_suggestedBreeds, Suggested animal type: $_suggestedAnimalType, Current breeds: $_breeds, '
'Current animal type: $_animalType');
} catch (e) {
debugPrint('UpdateBreedsFromImages - Error: $e');
final errorMessage = ApiService().extractErrorMessage(e);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(errorMessage, style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white)),
backgroundColor: Colors.red,
),
);
setState(() {
_error = errorMessage;
});
if (e is AuthException) {
Navigator.pushReplacementNamed(context, '/home');
}
}
} finally {
if (mounted) {
setState(() => _isLoading = false);
}
debugPrint('UpdateBreedsFromImages - Finished');
}
}

Future<void> _addBreedManually(String value) async {
debugPrint('AddBreedManually - Adding breed: $value');
if (value.isEmpty || _breeds.length >= 3) {
if (_breeds.length >= 3 && mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Maximum 3 breeds')),
);
}
debugPrint('AddBreedManually - Empty value or max breeds reached');
return;
}
final formattedBreed = value.trim().toLowerCase().capitalize();
if (!_breeds.contains(formattedBreed)) {
if (mounted) {
setState(() {
_breeds.add(formattedBreed);
_breedController.text = _breeds.join(', ');
_error = null;
});
}
debugPrint('AddBreedManually - Added breed: $formattedBreed');
}
_breedController.clear();
}

Future<void> _removeBreed(int index) async {
debugPrint('RemoveBreed - Removing breed at index $index');
if (mounted) {
setState(() {
_breeds.removeAt(index);
_breedController.text = _breeds.join(', ');
});
}
}

Future<void> _showKeywordsDialog() async {
final availableKeywords = _availableKeywords.where((keyword) => !_selectedKeywords.contains(keyword)).toList();
if (availableKeywords.isEmpty) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('No more keywords available')),
);
}
return;
}
final selected = await showDialog<String>(
context: context,
builder: (context) => AlertDialog(
title: Text('Select Keyword', style: GoogleFonts.lakkiReddy(fontSize: 24, color: const Color(0xFF7D6199))),
content: SingleChildScrollView(
child: Column(
children: availableKeywords
    .map((keyword) => ListTile(
title: Text(
keyword.replaceAll('_', ' ').toLowerCase().capitalize(),
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
),
onTap: () => Navigator.pop(context, keyword),
))
    .toList(),
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: Text('Cancel', style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68))),
),
],
),
);
if (selected != null && mounted) {
setState(() {
_selectedKeywords.add(selected);
_error = null;
});
debugPrint('ShowKeywordsDialog - Added keyword: $selected');
}
}

Future<void> _search() async {
debugPrint('Search - Started');
if (!_formKey.currentState!.validate()) {
debugPrint('Search - Form validation failed');
return;
}
if (mounted) {
setState(() {
_isLoading = true;
_error = null;
_searchStatus = 'Searching...';
});
}
try {
debugPrint('Search - Sending request with params: animalType=$_animalType, gender=$_gender, age=$_age, breeds=$_breeds, '
'color=$_color, keywords=${_selectedKeywords.isEmpty ? null : _selectedKeywords}, images=${_images.length}, location=${_locationController.text}');
final response = await ApiService().searchAnnouncements(
animalType: _animalType?.toLowerCase(),
gender: _gender,
age: _age,
breeds: _breeds.isNotEmpty ? _breeds : null,
color: _color,
keywords: _selectedKeywords.isNotEmpty ? _selectedKeywords.toList() : null,
images: _images.isNotEmpty ? _images : null,
location: _locationController.text.isNotEmpty ? _locationController.text : null,
);
debugPrint('Search - API response: $response');
if (mounted) {
setState(() {
_searchStatus = response != null && response.isNotEmpty ? 'Found ${response.length} announcements' : 'No announcements found';
});
debugPrint('Search - Navigating to AnnouncementsListScreen with ${response?.length ?? 0} announcements');
final announcements = response?.map((json) => Announcement.fromJson(json)).toList() ?? [];
await Navigator.push(
context,
MaterialPageRoute(
builder: (context) => AnnouncementsListScreen(announcements: announcements),
),
);
if (mounted) {
setState(() {
_searchStatus = null;
});
}
}
} catch (e) {
debugPrint('Search - Error: $e');
final errorMessage = ApiService().extractErrorMessage(e);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(errorMessage, style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white)),
backgroundColor: Colors.red,
),
);
setState(() {
_error = errorMessage;
_searchStatus = null;
});
if (e is AuthException) {
Navigator.pushReplacementNamed(context, '/home');
}
}
} finally {
if (mounted) {
setState(() => _isLoading = false);
}
debugPrint('Search - Finished');
}
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
debugPrint('Image file error: ${_images[index].path}, error: $error');
return const Icon(Icons.error, size: 100, color: Color(0xFFD87A68));
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
child: const Center(child: Icon(Icons.add, color: Color(0xFF7D6199), size: 40)),
),
);
}

Widget _buildBreedContainer(int index) {
return Container(
margin: const EdgeInsets.symmetric(vertical: 4.0),
padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
decoration: BoxDecoration(
border: Border.all(color: const Color(0xFFF2A03D)),
borderRadius: BorderRadius.circular(8),
color: const Color(0xFFFFFBF2),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Flexible(
child: Text(
_breeds[index],
style: GoogleFonts.oldenburg(fontSize: 16, color: const Color(0xFF7D6199)),
overflow: TextOverflow.ellipsis,
),
),
IconButton(
icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
onPressed: () => _removeBreed(index),
),
],
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
side: BorderSide(color: _selectedKeywords.length >= 5 ? const Color(0xFFF2A03D) : const Color(0xFFF2A03D)),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
onPressed: _selectedKeywords.length >= 5
? () {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Maximum 5 keywords allowed!',
style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.white),
),
duration: const Duration(seconds: 2),
backgroundColor: Colors.red,
),
);
}
}
    : () => _showKeywordsDialog(),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
'Select Keywords',
style: GoogleFonts.oldenburg(
fontSize: 18,
color: _selectedKeywords.length >= 5 ? Colors.grey : const Color(0xFFF2A03D),
fontWeight: FontWeight.bold,
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
keyword.replaceAll('_', ' ').toLowerCase().capitalize(),
style: GoogleFonts.oldenburg(fontSize: 16, color: const Color(0xFF7D6199)),
),
backgroundColor: const Color(0xFFFFFBF2),
shape: RoundedRectangleBorder(
side: const BorderSide(color: Color(0xFFF2A03D)),
borderRadius: BorderRadius.circular(16),
),
deleteIcon: const Icon(Icons.close, color: Color(0xFF7D6199), size: 18),
onDeleted: () {
if (mounted) {
setState(() {
_selectedKeywords.remove(keyword);
_error = null;
});
}
debugPrint('RemoveKeyword - Removed keyword: $keyword');
},
);
}).toList(),
),
],
);
}

Widget _buildLocationField() {
final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
debugPrint('BuildLocationField - Using GOOGLE_PLACES_API_KEY=$apiKey');
return GooglePlaceAutoCompleteTextField(
textEditingController: _locationController,
googleAPIKey: apiKey,
focusNode: _locationFocusNode,
inputDecoration: InputDecoration(
labelText: 'Location',
border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
filled: true,
fillColor: const Color(0xFFFFFBF2),
),
debounceTime: 800,
countries: [],
language: "en",
isLatLngRequired: false,
getPlaceDetailWithLatLng: (Prediction prediction) {
debugPrint('BuildLocationField - Selected place: ${prediction.description}');
_locationController.text = prediction.description ?? '';
},
itemClick: (Prediction prediction) {
debugPrint('BuildLocationField - Item clicked: ${prediction.description}');
_locationController.text = prediction.description ?? '';
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

@override
Widget build(BuildContext context) {
debugPrint('Build - Rendering SearchAnnouncementsScreen');
return Scaffold(
backgroundColor: const Color(0xFFFFDAB9),
appBar: AppBar(
backgroundColor: Colors.transparent,
elevation: 0,
title: Text(
'Search Announcements',
style: GoogleFonts.oldenburg(fontSize: 20, color: const Color(0xFF7D6199), fontWeight: FontWeight.bold),
),
),
body: Padding(
padding: const EdgeInsets.all(16.0),
child: Form(
key: _formKey,
child: SingleChildScrollView(
physics: const AlwaysScrollableScrollPhysics(),
child: Column(
children: [
if (_error != null)
Padding(
padding: const EdgeInsets.only(bottom: 16.0),
child: Text(
_error!,
style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
textAlign: TextAlign.center,
),
),
DropdownButtonFormField<String>(
value: _animalType,
items: ['Dog', 'Cat']
    .map((type) => DropdownMenuItem(
value: type,
child: Text(type, style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199))),
))
    .toList(),
onChanged: (value) {
if (mounted) {
setState(() => _animalType = value);
}
},
decoration: InputDecoration(
labelText: 'Animal Type',
border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
filled: true,
fillColor: const Color(0xFFFFFBF2),
),
),
const SizedBox(height: 16),
DropdownButtonFormField<String>(
value: _gender,
items: ['M', 'F']
    .map((gender) => DropdownMenuItem(
value: gender,
child: Text(gender, style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199))),
))
    .toList(),
onChanged: (value) {
if (mounted) {
setState(() => _gender = value);
}
},
decoration: InputDecoration(
labelText: 'Gender',
border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
filled: true,
fillColor: const Color(0xFFFFFBF2),
),
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
onChanged: (value) {
if (mounted) {
_age = value.isEmpty ? null : int.tryParse(value);
}
},
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
),
const SizedBox(height: 16),
TextFormField(
controller: _breedController,
decoration: InputDecoration(
labelText: 'Add Breed',
border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D))),
focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2)),
labelStyle: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFFD87A68)),
filled: true,
fillColor: const Color(0xFFFFFBF2),
),
onFieldSubmitted: _addBreedManually,
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
),
if (_breeds.isNotEmpty)
Wrap(
spacing: 8.0,
runSpacing: 4.0,
children: List.generate(_breeds.length, (index) => _buildBreedContainer(index)),
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
onChanged: (value) {
if (mounted) {
_color = value.isEmpty ? null : value;
}
},
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF7D6199)),
),
const SizedBox(height: 16),
_buildLocationField(),
const SizedBox(height: 16),
Text(
'Keywords:',
style: GoogleFonts.oldenburg(fontSize: 22, color: const Color(0xFFD87A68), fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),
_buildKeywordChips(),
const SizedBox(height: 16),
Text(
'Add Images (up to 3):',
style: GoogleFonts.oldenburg(fontSize: 22, color: const Color(0xFFD87A68), fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),
Row(
mainAxisAlignment: MainAxisAlignment.spaceEvenly,
children: List.generate(3, (index) => _buildImageContainer(index)),
),
if (_suggestedAnimalType != null)
Padding(
padding: const EdgeInsets.symmetric(vertical: 10),
child: Text(
'Suggested: ${_suggestedAnimalType!.capitalize()}',
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF8A9254), fontWeight: FontWeight.bold),
),
),
if (_searchStatus != null)
Padding(
padding: const EdgeInsets.symmetric(vertical: 10),
child: Text(
_searchStatus!,
style: GoogleFonts.oldenburg(fontSize: 18, color: const Color(0xFF8A9254), fontWeight: FontWeight.bold),
textAlign: TextAlign.center,
),
),
const SizedBox(height: 16),
_isLoading
? const CircularProgressIndicator(color: Color(0xFF7D6199))
    : ElevatedButton(
onPressed: _search,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFFFF8E8),
minimumSize: const Size(double.infinity, 50),
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
child: Text(
'Search',
style: GoogleFonts.lakkiReddy(fontSize: 24, color: const Color(0xFF7D6199), fontWeight: FontWeight.bold),
),
),
],
),
),
),
),
);
}
}