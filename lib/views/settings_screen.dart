import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/media_storage_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/status_viewmodel.dart';
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
  bool _isUpdatingProfilePicture = false;

  // Memoized result of File(_profilePictureUrl).existsSync(). Computing it
  // inside build() ran synchronous disk I/O on the UI thread on every frame —
  // including every frame of a dialog's keyboard animation — which was the main
  // source of the laggy keyboard. We recompute only when the path changes.
  String _resolvedPicturePath = '';
  bool _resolvedIsLocalPicture = false;

  bool get _hasLocalProfileImage {
    if (_profilePictureUrl != _resolvedPicturePath) {
      _resolvedPicturePath = _profilePictureUrl;
      _resolvedIsLocalPicture =
          _profilePictureUrl.isNotEmpty &&
          File(_profilePictureUrl).existsSync();
    }
    return _resolvedIsLocalPicture;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRemotePicture = prefs.getString('user_profile_picture') ?? '';
    final savedLocalPicture =
        prefs.getString('user_profile_picture_local') ?? '';
    final hasSavedLocalPicture =
        savedLocalPicture.isNotEmpty && File(savedLocalPicture).existsSync();
    if (!hasSavedLocalPicture && savedLocalPicture.isNotEmpty) {
      await prefs.remove('user_profile_picture_local');
      await prefs.remove('user_profile_picture_cache_key');
    }
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _phoneNumber = prefs.getString('user_phone') ?? '';
      _currentAbout = prefs.getString('user_about') ?? 'Available';
      _profilePictureUrl = hasSavedLocalPicture
          ? savedLocalPicture
          : savedRemotePicture;
      _isLoadingProfile = false;
    });

    try {
      final result = await ApiService().getProfile();
      final rawUser = result['user'];
      if (rawUser is! Map) return;

      final name = rawUser['name']?.toString() ?? '';
      final phone = rawUser['phone_number']?.toString() ?? '';
      final about = rawUser['about']?.toString() ?? 'Available';
      final picture = rawUser['profile_picture']?.toString() ?? '';
      final storedPictureKey = prefs.getString(
        'user_profile_picture_cache_key',
      );
      final previousPictureKey =
          storedPictureKey ??
          (hasSavedLocalPicture && savedRemotePicture.isNotEmpty
              ? MediaStorageService.instance.profileCacheKey(savedRemotePicture)
              : null);
      final pictureKey = picture.isEmpty
          ? ''
          : MediaStorageService.instance.profileCacheKey(picture);

      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_about', about);
      if (picture.isEmpty) {
        await prefs.remove('user_profile_picture');
        await prefs.remove('user_profile_picture_local');
        await prefs.remove('user_profile_picture_cache_key');
        await MediaStorageService.instance.deleteLocalFile(
          hasSavedLocalPicture ? savedLocalPicture : null,
        );
      } else {
        await prefs.setString('user_profile_picture', picture);
      }

      if (!mounted) return;
      setState(() {
        _userName = name;
        _phoneNumber = phone;
        _currentAbout = about;
        if (picture.isEmpty) {
          _profilePictureUrl = '';
        } else if (!hasSavedLocalPicture || previousPictureKey != pictureKey) {
          _profilePictureUrl = picture;
        }
      });

      if (picture.isNotEmpty &&
          (!hasSavedLocalPicture || previousPictureKey != pictureKey)) {
        final cachedPicture = await MediaStorageService.instance
            .cacheProfilePicture(picture);
        if (cachedPicture != null) {
          await prefs.setString('user_profile_picture_local', cachedPicture);
          await prefs.setString('user_profile_picture_cache_key', pictureKey);
          if (hasSavedLocalPicture && savedLocalPicture != cachedPicture) {
            await MediaStorageService.instance.deleteLocalFile(
              savedLocalPicture,
            );
          }
          if (mounted) {
            setState(() => _profilePictureUrl = cachedPicture);
          }
        }
      } else if (picture.isNotEmpty &&
          hasSavedLocalPicture &&
          storedPictureKey == null) {
        await prefs.setString('user_profile_picture_cache_key', pictureKey);
      }
    } catch (error) {
      debugPrint('Unable to refresh profile: $error');
    }
  }

  Future<void> _showEditNameDialog() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: _userName),
    );
    if (!mounted || newName == null) return;
    if (newName.isNotEmpty && newName != _userName) {
      await _updateProfile(name: newName);
    }
  }

  Future<void> _pickAndUpdateProfilePicture() async {
    if (_isUpdatingProfilePicture) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final previousPicture = _profilePictureUrl;
      setState(() {
        _profilePictureUrl = pickedFile.path;
        _isUpdatingProfilePicture = true;
      });
      final success = await _updateProfile(imagePath: pickedFile.path);
      if (!mounted) return;
      setState(() {
        if (!success) _profilePictureUrl = previousPicture;
        _isUpdatingProfilePicture = false;
      });
    }
  }

  Future<void> _handleProfilePictureTap() async {
    if (_isUpdatingProfilePicture) return;
    if (_profilePictureUrl.isEmpty) {
      await _pickAndUpdateProfilePicture();
      return;
    }

    final isLocal = _hasLocalProfileImage;
    final ImageProvider previewProvider = isLocal
        ? FileImage(File(_profilePictureUrl))
        : CachedNetworkImageProvider(ApiService.mediaUrl(_profilePictureUrl));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 58,
                backgroundColor: Colors.grey[200],
                backgroundImage: previewProvider,
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryColor,
                ),
                title: const Text('Change photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUpdateProfilePicture();
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeProfilePicture();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _updateProfile({
    String? name,
    String? imagePath,
    String? about,
    bool removeProfilePicture = false,
  }) async {
    final authProvider = Provider.of<AuthViewModel>(context, listen: false);
    try {
      final nameToSend = name ?? _userName;
      final aboutToSend = about ?? _currentAbout;
      final success = await authProvider.completeProfile(
        nameToSend,
        imagePath,
        about: aboutToSend,
        removeProfilePicture: removeProfilePicture,
      );
      if (success && mounted) {
        final prefs = await SharedPreferences.getInstance();
        if (name != null) {
          await prefs.setString('user_name', name);
        }
        if (about != null) {
          await prefs.setString('user_about', about);
        }
        final savedPicture = prefs.getString('user_profile_picture') ?? '';
        final savedLocalPicture =
            prefs.getString('user_profile_picture_local') ?? '';
        final displayPicture =
            savedLocalPicture.isNotEmpty && File(savedLocalPicture).existsSync()
            ? savedLocalPicture
            : savedPicture;
        setState(() {
          if (name != null) _userName = name;
          if (about != null) _currentAbout = about;
          if (imagePath != null || removeProfilePicture) {
            _profilePictureUrl = displayPicture;
          }
        });
        if (mounted) {
          context.read<StatusViewModel>().refreshLocalProfile();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        }
        return true;
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update profile: $error')),
        );
      }
    }
    return false;
  }

  Future<void> _removeProfilePicture() async {
    if (_isUpdatingProfilePicture || _profilePictureUrl.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your current profile photo will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingProfilePicture = true);
    await _updateProfile(removeProfilePicture: true);
    if (mounted) setState(() => _isUpdatingProfilePicture = false);
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
      await context.read<AuthViewModel>().logout();
      if (!mounted) return;
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
    final bool hasLocalImage = _hasLocalProfileImage;
    final bool hasNetworkImage =
        _profilePictureUrl.isNotEmpty && !hasLocalImage;

    return Scaffold(
      // This is a static list; the editing dialogs own the keyboard. Disabling
      // the resize keeps this screen from relaying out on every keyboard frame
      // underneath the dialog, so the dialog's keyboard stays smooth.
      resizeToAvoidBottomInset: false,
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
                          onTap: _isUpdatingProfilePicture
                              ? null
                              : _handleProfilePictureTap,
                          child: Stack(
                            clipBehavior: Clip.none,
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
                                            maxWidth: 200,
                                            maxHeight: 200,
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
                              if (_isUpdatingProfilePicture)
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0x66000000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
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

class _EditNameDialog extends StatefulWidget {
  final String initialName;

  const _EditNameDialog({required this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _save() {
    final newName = _controller.text.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(newName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Name'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          hintText: 'Enter your name',
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryColor),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('CANCEL')),
        TextButton(
          onPressed: _save,
          child: const Text(
            'SAVE',
            style: TextStyle(color: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }
}
