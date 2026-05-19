import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/status_viewmodel.dart';

class CreateTextStatusScreen extends StatefulWidget {
  const CreateTextStatusScreen({super.key});

  @override
  State<CreateTextStatusScreen> createState() => _CreateTextStatusScreenState();
}

class _CreateTextStatusScreenState extends State<CreateTextStatusScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Color> _backgrounds = const [
    AppColors.primaryColor,
    Color(0xFF128C7E),
    Color(0xFF25D366),
    Color(0xFF455A64),
    Color(0xFFE91E63),
  ];
  int _colorIndex = 0;
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = _backgrounds[_colorIndex];
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.white),
            onPressed: () {
              setState(() {
                _colorIndex = (_colorIndex + 1) % _backgrounds.length;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a status',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                onPressed: _canPost ? _postStatus : null,
                child: _isPosting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: background),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canPost => !_isPosting && _controller.text.trim().isNotEmpty;

  Future<void> _postStatus() async {
    setState(() => _isPosting = true);
    final color = _backgrounds[_colorIndex];
    final colorValue = '#${color.toARGB32().toRadixString(16).substring(2)}';
    try {
      await context.read<StatusViewModel>().createTextStatus(
        _controller.text.trim(),
        backgroundColor: colorValue,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }
}
