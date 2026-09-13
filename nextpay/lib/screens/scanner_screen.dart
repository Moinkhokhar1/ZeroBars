import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'payment_sheet_screen.dart';
import '../services/api_service.dart';

// ── Design tokens ───────────────────────────────────────────────
// Camera screens stay dark for viewfinder contrast, but the accent
// color matches the purple used across the rest of the app.
const _scrim = Color(0xFF14141A);
const _textOnDark = Colors.white;
const _mutedOnDark = Color(0xFFA3A3AC);
const _purple = Color(0xFF534AB7);

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _scanned = false;
  bool _isReadingImage = false;
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScanned(BarcodeCapture capture) async {
  if (_scanned) return;

  final barcodes = capture.barcodes;
  if (barcodes.isEmpty) return;

  final data = barcodes.first.rawValue;
  if (data == null || data.trim().isEmpty) return;

  setState(() => _scanned = true);

  String? receiverId;
  String? receiverName;
  String? receiverPhone;

  try {
    final parsed = Map<String, dynamic>.from(jsonDecode(data));

    receiverId = parsed["userId"]?.toString();
    receiverName = parsed["receiverName"]?.toString();
    receiverPhone = parsed["receiverPhone"]?.toString();
  } catch (_) {
    receiverId = data.trim();
  }

  if (receiverId == null || receiverId!.isEmpty) {
    setState(() => _scanned = false);
    _showAlert(
      "Invalid QR code",
      "This QR code does not contain a valid ZeroBars user ID.",
    );
    return;
  }

  // IMPORTANT:
  // QR itself already contains the receiver identity.
  // Do not require internet to continue.
  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentSheetScreen(
        receiverId: receiverId!,
        receiverName: receiverName ?? "ZeroBars User",
        receiverPhone: receiverPhone ?? "",
      ),
    ),
  );
}

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked =
      await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isReadingImage = true);

      final BarcodeCapture? capture =
      await _controller.analyzeImage(picked.path);

      if (!mounted) return;
      setState(() => _isReadingImage = false);

      if (capture == null || capture.barcodes.isEmpty) {
        _showAlert(
          "No QR code found",
          "We couldn't find a QR code in that image. Try a clearer photo.",
        );
        return;
      }

      _handleBarcodeScanned(capture);
    } catch (e) {
      if (mounted) setState(() => _isReadingImage = false);
      _showAlert("Error", "Couldn't read that image. Please try again.");
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scrim,
      body: Column(
        children: [
          // HEADER
          Container(
            color: _scrim,
            padding: EdgeInsets.fromLTRB(
              16,
              Theme.of(context).platform == TargetPlatform.iOS ? 54 : 40,
              16,
              16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back_rounded,
                        color: _textOnDark, size: 22),
                  ),
                ),
                const Text(
                  "Scan QR",
                  style: TextStyle(
                      color: _textOnDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: _isReadingImage ? null : _pickFromGallery,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: _isReadingImage
                        ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: _textOnDark,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.photo_library_outlined,
                        color: _textOnDark, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // CAMERA
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _scanned ? (_) {} : _handleBarcodeScanned,
                ),
                _buildOverlay(),
              ],
            ),
          ),

          // FOOTER
          Container(
            color: _scrim,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(
              children: [
                const Text(
                  "Point your camera at the recipient's QR code",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _mutedOnDark, fontSize: 13),
                ),
                if (_scanned) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: _purple,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _scanned = false),
                        child: const Padding(
                          padding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          child: Text(
                            "Scan again",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _isReadingImage ? null : _pickFromGallery,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            color: _mutedOnDark, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _isReadingImage
                              ? "Reading image…"
                              : "Select QR from gallery",
                          style: const TextStyle(
                              color: _mutedOnDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        Expanded(child: Container(color: Colors.black.withOpacity(0.55))),
        SizedBox(
          height: 260,
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.black.withOpacity(0.55))),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  children: [
                    _corner(top: 0, left: 0, borderTop: true, borderLeft: true),
                    _corner(top: 0, right: 0, borderTop: true, borderRight: true),
                    _corner(
                        bottom: 0, left: 0, borderBottom: true, borderLeft: true),
                    _corner(
                        bottom: 0,
                        right: 0,
                        borderBottom: true,
                        borderRight: true),
                  ],
                ),
              ),
              Expanded(child: Container(color: Colors.black.withOpacity(0.55))),
            ],
          ),
        ),
        Expanded(child: Container(color: Colors.black.withOpacity(0.55))),
      ],
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool borderTop = false,
    bool borderBottom = false,
    bool borderLeft = false,
    bool borderRight = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: borderTop
                ? const BorderSide(color: _purple, width: 4)
                : BorderSide.none,
            bottom: borderBottom
                ? const BorderSide(color: _purple, width: 4)
                : BorderSide.none,
            left: borderLeft
                ? const BorderSide(color: _purple, width: 4)
                : BorderSide.none,
            right: borderRight
                ? const BorderSide(color: _purple, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
