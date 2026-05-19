import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'contact_sync_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? selectedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (selectedImage != null) {
      setState(() {
        _image = File(selectedImage.path);
      });
    }
  }

  void _completeProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final authProvider = Provider.of<AuthViewModel>(context, listen: false);
    try {
      bool success = await authProvider.completeProfile(
        _nameController.text.trim(),
        _image?.path,
      );

      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ContactSyncScreen(),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile info", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Please provide your name and an optional profile photo",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                   CircleAvatar(
                    radius: 64,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null 
                      ? Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400])
                      : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: "Type your name here",
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              onPressed: _completeProfile,
              child: const Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
