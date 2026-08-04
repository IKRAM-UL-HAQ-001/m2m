import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';
import 'web_auth_viewmodel.dart';

/// Public landing page for M2M Web: renders the QR that the phone app scans to
/// authorise this browser session, laid out like the WhatsApp Web login page —
/// brand mark pinned top-left, one centred card with numbered instructions on
/// the left and the live QR on the right, legal/marketing footnotes below.

const _pageBackground = Color(0xFFF7EFF8);
const _cardBorder = Color(0xFFDFD2E1);
const _ink = Color(0xFF15121A);
const _bodyInk = Color(0xFF221E28);
const _mutedInk = Color(0xFF6B6575);
const _faintInk = Color(0xFFA29AA8);
const _stepRing = Color(0xFFC9C1CE);

/// Marketing-site pages linked from the footer. The React site is served from
/// msg2msg.com; this Flutter client lives on web.msg2msg.com (see deploy/).
const _siteUrl = 'https://msg2msg.com';
const _downloadUrl = '$_siteUrl/download';
const _helpUrl = '$_siteUrl/contact';
const _privacyUrl = '$_siteUrl/privacy';

/// Below this width the card stacks the QR above the instructions.
const _wideBreakpoint = 860.0;

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WebAuthViewModel>().startWebLinking();
    });
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<WebAuthViewModel>();
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          // Top padding clears the absolutely-positioned brand
                          // header so the card never slides under it.
                          // Bottom padding exceeds the top so the centred
                          // block lands slightly above the optical middle,
                          // matching the reference.
                          padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 16,
                            96,
                            wide ? 24 : 16,
                            56,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _card(auth, wide),
                                const SizedBox(height: 30),
                                _pageFooter(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(left: 32, top: 24, child: _BrandHeader()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(WebAuthViewModel auth, bool wide) {
    return Container(
      // Flat card: the reference sits on the tinted page with a hairline
      // border and no shadow.
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(
        wide ? 48 : 26,
        wide ? 46 : 32,
        wide ? 48 : 26,
        wide ? 40 : 30,
      ),
      child: wide ? _wideBody(auth) : _narrowBody(auth),
    );
  }

  Widget _wideBody(WebAuthViewModel auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The QR is flush with the top of the content box; the heading
            // starts a little lower, as in the reference.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _instructions(),
              ),
            ),
            const SizedBox(width: 44),
            _QrPanel(auth: auth),
          ],
        ),
        const SizedBox(height: 44),
        Align(
          alignment: Alignment.centerRight,
          child: _ArrowLink(
            label: 'Get a new code',
            onTap: () => context.read<WebAuthViewModel>().startWebLinking(),
          ),
        ),
      ],
    );
  }

  Widget _narrowBody(WebAuthViewModel auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(),
        const SizedBox(height: 26),
        Center(child: _QrPanel(auth: auth)),
        const SizedBox(height: 30),
        _stepsBlock(),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: _ArrowLink(
            label: 'Get a new code',
            onTap: () => context.read<WebAuthViewModel>().startWebLinking(),
          ),
        ),
      ],
    );
  }

  Widget _instructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [_title(), const SizedBox(height: 34), _stepsBlock()],
    );
  }

  Widget _title() {
    return const Text(
      'Scan to log in',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        color: _ink,
      ),
    );
  }

  Widget _stepsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _StepList(),
        const SizedBox(height: 22),
        _ExternalLink(label: 'Need help?', onTap: () => _open(_helpUrl)),
      ],
    );
  }

  Widget _pageFooter() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            const Padding(
              // Sits on the same baseline as the link, whose rule hangs 3px
              // below its text.
              padding: EdgeInsets.only(bottom: 4, right: 8),
              child: Text(
                "Don't have an M2M account?",
                style: TextStyle(fontSize: 15, height: 1.2, color: _bodyInk),
              ),
            ),
            _ExternalLink(
              label: 'Get started',
              onTap: () => _open(_downloadUrl),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 15, color: _mutedInk),
            SizedBox(width: 7),
            Text(
              'Your personal messages are end-to-end encrypted',
              style: TextStyle(fontSize: 14, color: _mutedInk),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _open(_privacyUrl),
            child: const Text(
              'Terms & Privacy Policy',
              style: TextStyle(fontSize: 12, color: _faintInk),
            ),
          ),
        ),
      ],
    );
  }
}

/// Brand lockup pinned to the top-left corner of the page.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BrandMark(size: 30, radius: 8),
        SizedBox(width: 9),
        Text(
          'M2M',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }
}

/// The app icon, rounded. Used in the header, inline in step 1 and at the
/// centre of the QR.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Numbered steps joined by a vertical connector line, WhatsApp-Web style.
class _StepList extends StatelessWidget {
  const _StepList();

  static const _bodyStyle = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: _bodyInk,
  );
  static const _boldStyle = TextStyle(fontWeight: FontWeight.w600);

  List<InlineSpan> get _steps => const [
    TextSpan(
      children: [
        TextSpan(text: 'Open '),
        TextSpan(text: 'M2M', style: _boldStyle),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: _BrandMark(size: 18, radius: 5),
          ),
        ),
        TextSpan(text: 'on your phone'),
      ],
    ),
    TextSpan(
      children: [
        TextSpan(text: 'Tap '),
        TextSpan(text: 'Menu', style: _boldStyle),
        TextSpan(text: ', then '),
        TextSpan(text: 'Linked devices', style: _boldStyle),
      ],
    ),
    TextSpan(
      children: [
        TextSpan(text: 'Tap '),
        TextSpan(text: 'Link a device', style: _boldStyle),
      ],
    ),
    TextSpan(text: 'Point your phone at this screen to scan the QR code'),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < steps.length; i++)
          _step(i + 1, steps[i], isLast: i == steps.length - 1),
      ],
    );
  }

  Widget _step(int number, InlineSpan text, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _stepRing),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(fontSize: 12.5, color: _bodyInk),
                  ),
                ),
                // The connector runs through the row's bottom padding, so the
                // line always ends exactly at the next circle.
                if (!isLast)
                  Expanded(child: Container(width: 1, color: _stepRing)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 20),
              child: Text.rich(text, style: _bodyStyle),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live QR plus its expiry caption.
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.auth});

  final WebAuthViewModel auth;

  static const double _size = 232;

  String _countdown(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    return '$minutes:${(safe % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final token = auth.linkToken;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: token == null
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryColor,
                    ),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: token,
                      size: _size,
                      padding: EdgeInsets.zero,
                      version: QrVersions.auto,
                      // High correction so the centred brand mark can cover
                      // part of the code without breaking the scan.
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: _ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: _ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const _BrandMark(size: 38, radius: 9),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          token == null
              ? 'Preparing your code…'
              : 'Code refreshes in ${_countdown(auth.linkCountdown)}',
          style: const TextStyle(fontSize: 12.5, color: _faintInk),
        ),
      ],
    );
  }
}

/// Link label: dark text over a brand-coloured rule. Drawn as a bottom border
/// rather than a TextDecoration so the rule clears the descenders, the way the
/// reference design does — Flutter has no underline-offset knob.
class _LinkLabel extends StatelessWidget {
  const _LinkLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.primaryColor, width: 1.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }
}

/// Underlined link with a trailing "opens elsewhere" arrow.
class _ExternalLink extends StatelessWidget {
  const _ExternalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _LinkLabel(label),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.north_east, size: 14, color: _ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Underlined link with a trailing chevron, used for the in-page action at the
/// bottom-right of the card.
class _ArrowLink extends StatelessWidget {
  const _ArrowLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _LinkLabel(label),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: _ink),
          ],
        ),
      ),
    );
  }
}
