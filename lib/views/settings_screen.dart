import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = '';
  String _phoneNumber = '';
  String _currentAbout = 'Available';
  String _profilePictureUrl = '';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _phoneNumber = prefs.getString('user_phone') ?? '';
      _currentAbout = prefs.getString('user_about') ?? 'Available';
      _profilePictureUrl = prefs.getString('user_profile_picture') ?? '';
      _isLoadingProfile = false;
    });
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              controller.dispose();
              Navigator.pop(context);
              if (newName.isNotEmpty && newName != _userName) {
                await _updateProfile(name: newName);
              }
            },
            child: const Text(
              'SAVE',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpdateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _updateProfile(imagePath: pickedFile.path);
    }
  }

  Future<void> _updateProfile({
    String? name,
    String? imagePath,
    String? about,
  }) async {
    final authProvider = Provider.of<AuthViewModel>(context, listen: false);
    try {
      final nameToSend = name ?? _userName;
      final aboutToSend = about ?? _currentAbout;
      final success = await authProvider.completeProfile(
        nameToSend,
        imagePath,
        about: aboutToSend,
      );
      if (success && mounted) {
        final prefs = await SharedPreferences.getInstance();
        if (name != null) {
          await prefs.setString('user_name', name);
        }
        if (about != null) {
          await prefs.setString('user_about', about);
        }
        if (imagePath != null) {
          // Profile picture URL will be updated on next fetch; clear local cache
          await prefs.remove('user_profile_picture');
        }
        setState(() {
          if (name != null) _userName = name;
          if (about != null) _currentAbout = about;
          if (imagePath != null) _profilePictureUrl = imagePath;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _updateAbout(String about) async {
    final trimmed = about.trim();
    if (trimmed.isEmpty || trimmed == _currentAbout) return;
    await _updateProfile(about: trimmed);
  }

  void _showAboutPicker(BuildContext context) {
    final presets = [
      'Available',
      'Busy',
      'At work',
      'At school',
      'At the gym',
      'Battery about to die',
      'Can\'t talk, WhatsApp only',
      'Only emergency calls',
      'In a meeting',
      'Sleeping',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...presets.map(
                (option) => ListTile(
                  leading: _currentAbout == option
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primaryColor,
                        )
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                  title: Text(option),
                  onTap: () {
                    _updateAbout(option);
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primaryColor),
                title: const Text(
                  'Custom...',
                  style: TextStyle(color: AppColors.primaryColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomAboutDialog(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomAboutDialog(BuildContext context) {
    final controller = TextEditingController(text: _currentAbout);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Custom About'),
        content: TextField(
          controller: controller,
          maxLength: 139,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Write something...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              controller.dispose();
              _updateAbout(value);
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a fresh OTP to confirm account deletion.'),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              otpController.dispose();
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final otp = otpController.text.trim();
              otpController.dispose();
              _deleteAccount(otp);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(String otp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final apiService = ApiService();
    bool success = false;
    try {
      success = await apiService.deleteAccount(otp);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // Hide loading indicator

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account and data deleted successfully')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete account. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLocalImage =
        _profilePictureUrl.isNotEmpty && !_profilePictureUrl.startsWith('http');
    final bool hasNetworkImage =
        _profilePictureUrl.isNotEmpty && _profilePictureUrl.startsWith('http');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  // Profile Section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUpdateProfilePicture,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: hasLocalImage
                                    ? FileImage(File(_profilePictureUrl))
                                    : hasNetworkImage
                                    ? CachedNetworkImageProvider(
                                            ApiService.mediaUrl(
                                              _profilePictureUrl,
                                            ),
                                          )
                                          as ImageProvider
                                    : null,
                                child: (!hasLocalImage && !hasNetworkImage)
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primaryColor,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _userName.isNotEmpty ? _userName : 'Set your name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _phoneNumber,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAbout,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Edit Name
                  ListTile(
                    leading: const Icon(
                      Icons.person,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('Name'),
                    subtitle: Text(
                      _userName.isNotEmpty ? _userName : 'Tap to set your name',
                    ),
                    trailing: const Icon(
                      Icons.edit,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onTap: _showEditNameDialog,
                  ),
                  const Divider(indent: 70),

                  // About
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('About'),
                    subtitle: Text(_currentAbout),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () => _showAboutPicker(context),
                  ),
                  const Divider(indent: 70),

                  // Phone (non-editable)
                  ListTile(
                    leading: const Icon(
                      Icons.phone,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('Phone'),
                    subtitle: Text(
                      _phoneNumber.isNotEmpty ? _phoneNumber : 'Not set',
                    ),
                  ),
                  const Divider(),

                  // Delete Account
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Delete account and all data permanently',
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
      ),
    );
  }
}
