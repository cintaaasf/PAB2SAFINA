import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shimmer/shimmer.dart';

class AddPostScreen extends StatefulWidget {
  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _image;
  String? _base64Image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _latitude;
  double? _longtitude;
  String? _aiCategory;
  String? _aiDescription;
  bool _isGenerating = false;

  Future<void> _compressAndEncodeImage() async {
    if (_image == null) return;

    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.path,
        quality: 50,
      );
      if (compressedImage == null) return;

      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to compress image: $e')));
      }
    }
  }

  Future<void>? _pickImage(ImageSource source) async {
    try {
      final PickedFile = await _picker.pickImage(source: source);
      if (PickedFile != null) {
        setState(() {
          _image = File(PickedFile.path);
          _aiCategory = null;
          _aiDescription = null;
          _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        await _generateDescriptionWithAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _generateDescriptionWithAI() async {
    if (_image == null) return;
    setState(() => _isGenerating = true);
    try {
      final model = GenerativeModel(
        apiKey: 'AIzaSyBVG3xTeqUwj0lC-lih6dI5YekOJIKCdvg',
        model: 'gemini-1.5-pro',
      );

      final imageBytes = await _image!.readAsBytes();
      final content = Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart(
          'Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum'
          'dari daftar berikut: Jalan Rusak, Marka Pudar, Lampu mati, Trotoar rusak, '
          'Rambu rusak, Jembatan Rusak, Saluran air tersumbat, Sampah menumpuk, Sungai Tercemar '
          'Vandalisme, Banjir, dan lainnya.'
          'Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan'
          'Buat deskripsi singkat untuk laporan perbaikan, dan tambahkan permohonan perbaikan.'
          'Fokus pada kerusakan yang terlihat dan hindari spekulasi.\n\n'
          'Format output yang diinginkan:\n'
          'Kategori: [satu kategori yang dipilih]\n'
          'Deskripsi: [deskripsi singkat]',
        ),
      ]);

      final response = await model.generateContent([content]);
      final aiText = response.text;
      print('AI TEXT: $aiText');

      if (aiText != null && aiText.isNotEmpty) {
        final lines = aiText.split('\n');
        String? category;
        String? description;

        for (var line in lines) {
          final lower = line.toLowerCase();
          if (lower.startsWith('kategori:')) {
            category = line.substring(9).trim();
          } else if (lower.startsWith('deskripsi:')) {
            description = line.substring(10).trim();
          } else if (lower.startsWith('Keterangan')) {
            description = line.substring(11).trim();
          }
        }

        description ??= aiText.trim();

        setState(() {
          _aiCategory = category ?? 'Tidak diketahui';
          _aiDescription = description;
          _descriptionController.text = _aiDescription!;
        });
      }
    } catch (e) {
      debugPrint('Failed to generate description: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }

      try {
        final position = await Geolocator.getCurrentPosition(
                // locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
                )
            .timeout(const Duration(seconds: 10));
        setState(() {
          _latitude = position.latitude;
          _longtitude = position.longitude;
        });
      } catch (e) {
        debugPrint('Gagal mendapatkan lokasi: $e');
        setState(() {
          _latitude = null;
          _longtitude = null;
        });
      }
    }
  }

  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) return;

    setState(() => _isUploading = true);

    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengguna tidak ditemukan')),
      );
      return;
    }

    try {
      await _getLocation();

      //ambil nama lengkap dari koleksi user
      final userDoc =
          await FirebaseFirestore.instance.collection('user').doc(uid).get();
      final fullName = userDoc.data()?['fullName'] ?? 'Tanpa Nama';
      await FirebaseFirestore.instance.collection('post').add({
        'image': _base64Image,
        'description': _descriptionController.text,
        'createAt': now,
        'latitude': _latitude,
        'longtitude': _longtitude,
        'fullName': fullName, // <--- tambahkan ini
        'userID': uid, // optional : jika ingin simpan UID juga
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunggah postingan')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a Picture'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _image != null
                ? Image.file(
                    _image!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(Icons.add_a_photo, size: 50),
                      ),
                    ),
                  ),
            SizedBox(
              height: 10,
            ),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Add a brief description...',
                border: OutlineInputBorder(),
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}