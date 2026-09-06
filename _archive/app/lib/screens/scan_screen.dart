import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// A live barcode scanner (the data path it feeds is [ShopRepository.getProductByBarcode]).
///
/// Pushed as `/scan`; it POPS a `String` — the scanned (or hand-typed) code — or
/// null if the owner cancelled. So a caller does:
///
/// ```dart
/// final code = await context.push<String>('/scan');
/// if (code != null) { ... }
/// ```
///
/// It degrades gracefully in three ways, so nothing ever crashes and the owner
/// is never stuck:
///   * On a platform mobile_scanner does not support — a desktop `flutter run`
///     on Windows/Linux — the camera is NEVER constructed; the screen opens
///     straight on the manual-entry panel.
///   * When the camera can't start (permission denied, no camera, a driver
///     error) the live view is swapped for the same manual-entry panel with a
///     plain-English reason.
///   * Even with a working camera, "Type it in instead" is always one tap away.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  /// mobile_scanner ships implementations for Android, iOS, macOS and web only.
  /// On anything else (a Windows/Linux desktop demo) touching the controller
  /// throws, so we gate on the platform and never build it there. Uses
  /// [defaultTargetPlatform] rather than `dart:io` so this file also compiles
  /// for web (where `Platform` is unavailable).
  static bool get _cameraCapablePlatform {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  MobileScannerController? _controller;

  /// Guards against a double-pop: [onDetect] can fire many times a second, and
  /// a manual submit could race a late scan.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    if (_cameraCapablePlatform) {
      _controller = MobileScannerController(
        // The scanner keeps firing while a code stays in frame; noDuplicates
        // collapses that to one event per distinct code (belt-and-braces with
        // [_handled]).
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      WidgetsBinding.instance.addObserver(this);
      _start();
    }
  }

  void _start() {
    // start() surfaces failures on controller.value.error (which the UI reads),
    // so a thrown future here is nothing extra to handle — just don't let it go
    // uncaught.
    _controller?.start().catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.stop().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_handled) return;
    _handled = true;
    if (mounted) context.pop(code);
  }

  void _cancel() {
    if (mounted) context.pop();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;
    HapticFeedback.mediumImpact();
    _finish(code);
  }

  Future<void> _enterManually() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.kn.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KnRadius.sheet)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _ManualEntryPanel(
          title: 'Type the barcode in',
          message: 'The long number under the bars.',
          submitLabel: 'Use this barcode',
          onSubmit: (value) => Navigator.pop(sheetContext, value),
          onCancel: () => Navigator.pop(sheetContext),
        ),
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;

    if (!_cameraCapablePlatform) {
      // Desktop / unsupported: open straight on manual entry, no camera at all.
      return Scaffold(
        backgroundColor: kn.surface,
        appBar: _cancelAppBar(kn),
        body: SafeArea(
          child: _ManualEntryPanel(
            icon: Icons.no_photography_outlined,
            title: 'No camera to scan with',
            message:
                "This device can't scan with a camera. Type the barcode in — "
                'the long number under the bars.',
            submitLabel: 'Use this barcode',
            onSubmit: _finish,
            onCancel: _cancel,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller!,
          builder: (context, state, _) {
            if (state.error != null) {
              return _errorPanel(kn, state.error!);
            }
            return _liveView(kn, state);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _cancelAppBar(KnColors kn) {
    return AppBar(
      backgroundColor: kn.surface,
      foregroundColor: kn.textPrimary,
      elevation: 0,
      leading: TextButton(
        onPressed: _cancel,
        child: Text('Cancel',
            style: KnType.button.copyWith(color: kn.textPrimary)),
      ),
      leadingWidth: 88,
      title: Text('Scan a barcode',
          style: KnType.title3.copyWith(color: kn.textPrimary)),
    );
  }

  Widget _errorPanel(KnColors kn, MobileScannerException error) {
    String title;
    String message;
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        title = 'Camera is switched off for this app';
        message =
            'To scan, allow camera access in your phone Settings. Or type the '
            'barcode in below.';
      case MobileScannerErrorCode.unsupported:
        title = "This device can't scan";
        message =
            "The camera can't scan barcodes here. Type the barcode in below.";
      default:
        title = "The camera didn't start";
        message =
            'Something stopped the camera. Try again, or type the barcode in '
            'below.';
    }
    return Container(
      color: kn.surface,
      child: _ManualEntryPanel(
        icon: Icons.photo_camera_back_outlined,
        title: title,
        message: message,
        submitLabel: 'Use this barcode',
        onSubmit: _finish,
        onCancel: _cancel,
      ),
    );
  }

  Widget _liveView(KnColors kn, MobileScannerState state) {
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
        ),
        // Scrim + framing cutout. Decorative, so it never eats a tap.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ScannerOverlay(frameColor: kn.accentRed),
            ),
          ),
        ),
        // Top controls: cancel + torch. White glyphs read on the dark feed.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KnSpace.s2, vertical: KnSpace.s2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _cancel,
                  child: Text('Cancel',
                      style: KnType.button.copyWith(color: Colors.white)),
                ),
                _TorchButton(state: state, onToggle: _toggleTorch),
              ],
            ),
          ),
        ),
        // Bottom: instruction + always-available manual fallback.
        Positioned(
          left: KnSpace.s4,
          right: KnSpace.s4,
          bottom: KnSpace.s6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  'Point the camera at the barcode.',
                  textAlign: TextAlign.center,
                  style: KnType.body.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: KnSpace.s4),
              OutlinedButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.keyboard_outlined,
                    size: 20, color: Colors.white),
                label: Text('Type it in instead',
                    style: KnType.button.copyWith(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KnRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleTorch() {
    _controller?.toggleTorch().catchError((Object _) {});
  }
}

/// The torch (flash) toggle. Hidden when the device reports no torch, so the
/// owner never taps a dead control.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.state, required this.onToggle});

  final MobileScannerState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final torch = state.torchState;
    if (torch == TorchState.unavailable) return const SizedBox.shrink();
    final on = torch == TorchState.on;
    return IconButton(
      onPressed: onToggle,
      tooltip: on ? 'Turn the light off' : 'Turn the light on',
      icon: Icon(
        on ? Icons.flash_on : Icons.flash_off,
        color: Colors.white,
      ),
    );
  }
}

/// Paints a translucent scrim over the whole view with a clear, rounded cutout
/// in the middle, and a brand-red rule around it (brand red is legal here — a
/// non-text graphic on a dark surface, per the palette rules).
class _ScannerOverlay extends CustomPainter {
  const _ScannerOverlay({required this.frameColor});

  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutWidth = size.width * 0.8;
    final cutoutHeight = cutoutWidth * 0.62;
    final left = (size.width - cutoutWidth) / 2;
    final top = size.height * 0.30;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight),
      const Radius.circular(16),
    );

    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.6));

    canvas.drawRRect(
      cutout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = frameColor,
    );
  }

  @override
  bool shouldRepaint(_ScannerOverlay oldDelegate) =>
      oldDelegate.frameColor != frameColor;
}

/// A shared, keyboard-first panel for typing a barcode by hand. Used as the
/// desktop/no-camera screen, the camera-error screen, and the "Type it in
/// instead" bottom sheet.
class _ManualEntryPanel extends StatefulWidget {
  const _ManualEntryPanel({
    this.icon,
    required this.title,
    required this.message,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
  });

  final IconData? icon;
  final String title;
  final String message;
  final String submitLabel;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ManualEntryPanel> createState() => _ManualEntryPanelState();
}

class _ManualEntryPanelState extends State<_ManualEntryPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final hasText = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(KnSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 40, color: kn.textSecondary),
            const SizedBox(height: KnSpace.s4),
          ],
          Semantics(
            header: true,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: KnType.title3.copyWith(color: kn.textPrimary),
            ),
          ),
          const SizedBox(height: KnSpace.s2),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: KnType.body.copyWith(color: kn.textSecondary),
          ),
          const SizedBox(height: KnSpace.s6),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: KnType.body.copyWith(color: kn.textPrimary),
            decoration: InputDecoration(
              hintText: 'Barcode number',
              hintStyle: KnType.body.copyWith(color: kn.textSecondary),
              constraints: const BoxConstraints(minHeight: 52),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: KnSpace.s4, vertical: KnSpace.s3),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KnRadius.control),
                borderSide: BorderSide(color: kn.lineControl, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KnRadius.control),
                borderSide: BorderSide(color: kn.textPrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: KnSpace.s5),
          // Primary action — a filled pill, styled inline so this panel stays
          // self-contained (it renders over a black camera feed too).
          Semantics(
            button: true,
            enabled: hasText,
            label: widget.submitLabel,
            child: Opacity(
              opacity: hasText ? 1 : 0.4,
              child: Material(
                color: kn.fillRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KnRadius.pill),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: hasText ? _submit : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    alignment: Alignment.center,
                    child: Text(widget.submitLabel,
                        style: KnType.button.copyWith(color: kn.onFill)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KnSpace.s2),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text('Cancel',
                style: KnType.button.copyWith(color: kn.textPrimary)),
          ),
        ],
      ),
    );
  }
}
