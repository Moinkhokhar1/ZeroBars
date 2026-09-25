// import 'dart:io';
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter/services.dart';
// import 'package:zerobars/screens/login_screen.dart';
// import 'package:provider/provider.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:screenshot/screenshot.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/app_lock_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:gal/gal.dart';
// import 'dart:convert';
// import '../services/offline_wallet_service.dart';
// import '../providers/auth_provider.dart';
// import '../providers/theme_provider.dart';
// import '../app_colors.dart';
// import '../models/wallet.dart';
// import 'home_screen.dart';
// import 'scanner_screen.dart';
//
// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});
//
//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }
//
// class _ProfileScreenState extends State<ProfileScreen> {
//   final ScreenshotController _screenshotController = ScreenshotController();
//   // Dedicated controller backed by an always-mounted (offstage) widget so
//   // "Share QR code" works from the profile list row too, not only from
//   // inside the full-screen QR viewer where a Screenshot widget happens
//   // to be on screen.
//   final GlobalKey _shareCaptureKey = GlobalKey();
//   final ImagePicker _imagePicker = ImagePicker();
//   File? _profileImage;
//
//   // FIX: this used to be one fixed key ('profile_image_path') and one fixed
//   // filename ('profile_photo.jpg') shared by every account on the device.
//   // Whoever logged in last would overwrite the same file, so a new account
//   // on the same device would see the previous account's photo (or vice
//   // versa). Both the pref key AND the file on disk are now namespaced by
//   // the current user's id — this key format matches HomeScreen's
//   // `_profileImageKey`, since both screens must agree on where the photo
//   // for a given account lives.
//   String _profileImageKey(String userId) => 'profile_image_path_$userId';
//
//   String? _resolveUserId() {
//     final id = context.read<AuthProvider>().user?.id;
//     return (id != null && id.isNotEmpty) ? id : null;
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSavedImage();
//   }
//
//   // ── Persistence / image handling ────────────────────────────────────────
//
//   Future<void> _loadSavedImage() async {
//     final userId = _resolveUserId();
//     if (userId == null) {
//       if (mounted) setState(() => _profileImage = null);
//       return;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final path = prefs.getString(_profileImageKey(userId));
//     if (path != null) {
//       final file = File(path);
//       if (await file.exists()) {
//         if (mounted) setState(() => _profileImage = file);
//       } else {
//         await prefs.remove(_profileImageKey(userId));
//         if (mounted) setState(() => _profileImage = null);
//       }
//     } else {
//       if (mounted) setState(() => _profileImage = null);
//     }
//   }
//
//   Future<void> _saveImagePath(String userId, String path) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_profileImageKey(userId), path);
//   }
//
//   Future<void> _clearImagePath(String userId) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_profileImageKey(userId));
//   }
//
//   Future<File> _persistImage(String userId, File tempFile) async {
//     final appDir = await getApplicationDocumentsDirectory();
//     // Per-user filename — this is the part the earlier fix in HomeScreen
//     // was still missing. Even with a per-user pref key, every account was
//     // still writing to the same physical file ('profile_photo.jpg'), so
//     // the file's contents got overwritten by whichever account uploaded a
//     // photo most recently, corrupting the "old" account's saved path too.
//     final permanent = File('${appDir.path}/profile_photo_$userId.jpg');
//     return tempFile.copy(permanent.path);
//   }
//
//   // Future<void> _handleShare() async {
//   //   try {
//   //     // Always capture from the hidden, always-mounted widget below rather
//   //     // than _screenshotController, which only has something to capture
//   //     // while the full-screen QR viewer happens to be open. This is why
//   //     // the old "Share QR code" row on this screen silently did nothing.
//   //     final imageBytes = await _shareCaptureController.capture();
//   //     if (imageBytes == null) {
//   //       if (mounted) {
//   //         ScaffoldMessenger.of(context).showSnackBar(
//   //           const SnackBar(content: Text("Couldn't prepare QR code to share")),
//   //         );
//   //       }
//   //       return;
//   //     }
//   //
//   //     final dir = await getTemporaryDirectory();
//   //     final file = File(
//   //       '${dir.path}/nextpay_qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
//   //     );
//   //     await file.writeAsBytes(imageBytes);
//   //
//   //     if (!mounted) return;
//   //
//   //     final size = MediaQuery.of(context).size;
//   //     final rect = Rect.fromCenter(
//   //       center: Offset(size.width / 2, size.height * 0.75),
//   //       width: 200,
//   //       height: 50,
//   //     );
//   //
//   //     final result = await Share.shareXFiles(
//   //       [XFile(file.path)],
//   //       text: 'Scan to pay me on NextPay',
//   //       sharePositionOrigin: rect,
//   //     );
//   //
//   //     if (result.status == ShareResultStatus.dismissed) {
//   //       debugPrint("Share sheet dismissed by user");
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Share error: $e");
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         const SnackBar(content: Text("Couldn't share QR code. Try again.")),
//   //       );
//   //     }
//   //   }
//   // }
//
//   Future<void> _handleShare() async {
//     try {
//       // The share target is always mounted in the widget tree. Capture its
//       // RepaintBoundary directly instead of using ScreenshotController.
//       final boundaryContext = _shareCaptureKey.currentContext;
//
//       if (boundaryContext == null) {
//         debugPrint("QR share target is not mounted");
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Couldn't prepare QR code to share"),
//             ),
//           );
//         }
//         return;
//       }
//
//       final renderObject = boundaryContext.findRenderObject();
//
//       if (renderObject is! RenderRepaintBoundary) {
//         debugPrint(
//           "QR share target is not a RenderRepaintBoundary: "
//           "${renderObject.runtimeType}",
//         );
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Couldn't prepare QR code to share"),
//             ),
//           );
//         }
//         return;
//       }
//
//       final boundary = renderObject;
//
//       // Make sure Flutter has painted the target before calling toImage().
//       await WidgetsBinding.instance.endOfFrame;
//
//       if (boundary.debugNeedsPaint) {
//         await Future<void>.delayed(const Duration(milliseconds: 50));
//         await WidgetsBinding.instance.endOfFrame;
//       }
//
//       final image = await boundary.toImage(pixelRatio: 3.0);
//
//       final byteData = await image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );
//
//       image.dispose();
//
//       if (byteData == null) {
//         debugPrint("Failed to convert QR image to PNG bytes");
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Couldn't prepare QR code to share"),
//             ),
//           );
//         }
//         return;
//       }
//
//       final imageBytes = byteData.buffer.asUint8List();
//
//       final dir = await getTemporaryDirectory();
//
//       final file = File(
//         '${dir.path}/nextpay_qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
//       );
//
//       await file.writeAsBytes(imageBytes, flush: true);
//
//       if (!await file.exists()) {
//         throw Exception("QR share file was not created");
//       }
//
//       if (!mounted) return;
//
//       final size = MediaQuery.of(context).size;
//
//       final result = await Share.shareXFiles(
//         [
//           XFile(
//             file.path,
//             mimeType: 'image/png',
//             name: 'nextpay_qr.png',
//           ),
//         ],
//         text: 'Scan to pay me on NextPay',
//         sharePositionOrigin: Rect.fromCenter(
//           center: Offset(
//             size.width / 2,
//             size.height * 0.75,
//           ),
//           width: 200,
//           height: 50,
//         ),
//       );
//
//       if (result.status == ShareResultStatus.dismissed) {
//         debugPrint("Share sheet dismissed by user");
//       }
//     } catch (e, stackTrace) {
//       debugPrint("QR Share error: $e");
//       debugPrintStack(stackTrace: stackTrace);
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Couldn't share QR code. Try again."),
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _pickImage(ImageSource source) async {
//     final userId = _resolveUserId();
//     if (userId == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Please log in again to set a photo")),
//         );
//       }
//       return;
//     }
//     try {
//       final XFile? picked = await _imagePicker.pickImage(
//         source: source,
//         imageQuality: 85,
//         maxWidth: 512,
//         maxHeight: 512,
//       );
//       if (picked == null) return;
//       final permanent = await _persistImage(userId, File(picked.path));
//       await _saveImagePath(userId, permanent.path);
//       if (mounted) setState(() => _profileImage = permanent);
//     } catch (e) {
//       debugPrint("Image pick error: $e");
//     }
//   }
//
//   Future<void> _removeImage() async {
//     final userId = _resolveUserId();
//     if (_profileImage != null) {
//       try {
//         if (await _profileImage!.exists()) await _profileImage!.delete();
//       } catch (_) {}
//     }
//     if (userId != null) {
//       await _clearImagePath(userId);
//     }
//     if (mounted) setState(() => _profileImage = null);
//   }
//
//   Future<void> _handleLogout() async {
//     final auth = context.read<AuthProvider>();
//
//     final hasLockedBalance = (auth.user?.wallet?.lockedBalance ?? 0) > 0;
//
//     final prefs = await SharedPreferences.getInstance();
//     final key = "pending_transactions_${auth.user?.id}";
//     final pending = prefs.getStringList(key) ?? [];
//     final hasPendingTransactions = pending.isNotEmpty;
//
//     if (hasLockedBalance || hasPendingTransactions) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please sync all offline payments before logging out."),
//         ),
//       );
//       return;
//     }
//
//     await auth.logout();
//
//     if (!mounted) return;
//     Navigator.of(context).popUntil((route) => route.isFirst);
//   }
//
//   // ── Offline wallet recharge ──────────────────────────────────────────
//
//   Future<void> _showOfflineWalletSheet(AppColors c) async {
//     final auth = context.read<AuthProvider>();
//     final wallet = auth.user?.wallet;
//     if (wallet == null) return;
//
//     final availableBalance =
//     (wallet.balance - wallet.lockedBalance).clamp(0, wallet.balance);
//     final controller = TextEditingController();
//     bool isSubmitting = false;
//
//     await showModalBottomSheet(
//       context: context,
//       backgroundColor: c.surface,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (sheetContext) {
//         return StatefulBuilder(
//           builder: (sheetContext, setSheetState) {
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 20,
//                 right: 20,
//                 top: 20,
//                 bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 36,
//                       height: 4,
//                       margin: const EdgeInsets.only(bottom: 16),
//                       decoration: BoxDecoration(
//                         color: c.border,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ),
//                   ),
//                   Text(
//                     "Offline wallet",
//                     style: TextStyle(
//                         fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     "Recharge it from your main balance to spend offline. "
//                         "This is a real transaction — the amount is debited "
//                         "from your balance right now, so it's never lost or "
//                         "duplicated even if this device is lost before you sync.",
//                     style: TextStyle(fontSize: 13, color: c.textSecondary),
//                   ),
//                   const SizedBox(height: 16),
//                   Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       color: c.bg,
//                       borderRadius: BorderRadius.circular(14),
//                       border: Border.all(color: c.border),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text("Offline wallet balance",
//                                 style: TextStyle(fontSize: 12, color: c.textSecondary)),
//                             const SizedBox(height: 4),
//                             Text(
//                               "₹${wallet.offlineBalance.toStringAsFixed(0)}",
//                               style: TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.w700,
//                                   color: c.textPrimary),
//                             ),
//                           ],
//                         ),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text("Main balance",
//                                 style: TextStyle(fontSize: 12, color: c.textSecondary)),
//                             const SizedBox(height: 4),
//                             Text(
//                               "₹${availableBalance.toStringAsFixed(0)}",
//                               style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                   color: c.textSecondary),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   TextField(
//                     controller: controller,
//                     keyboardType: const TextInputType.numberWithOptions(decimal: false),
//                     style: TextStyle(color: c.textPrimary, fontSize: 16),
//                     decoration: InputDecoration(
//                       prefixText: "₹ ",
//                       hintText: "Amount to recharge, e.g. 100",
//                       filled: true,
//                       fillColor: c.bg,
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: BorderSide(color: c.border),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: c.purple,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(28),
//                         ),
//                       ),
//                       onPressed: isSubmitting
//                           ? null
//                           : () async {
//                         final amount = num.tryParse(controller.text.trim());
//                         if (amount == null || amount <= 0) {
//                           ScaffoldMessenger.of(sheetContext).showSnackBar(
//                             const SnackBar(content: Text("Enter a valid amount")),
//                           );
//                           return;
//                         }
//                         if (amount > availableBalance) {
//                           ScaffoldMessenger.of(sheetContext).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 "You only have ₹${availableBalance.toStringAsFixed(0)} "
//                                     "in your main balance.",
//                               ),
//                             ),
//                           );
//                           return;
//                         }
//
//                         setSheetState(() => isSubmitting = true);
//
//                         // This is the actual server call — main balance is
//                         // debited and offline_balance is credited
//                         // atomically, right now, while we're online.
//                         final result = await OfflineWalletService.recharge(amount);
//
//                         setSheetState(() => isSubmitting = false);
//
//                         if (result["success"] == true) {
//                           final updatedWallet = result["wallet"] as Wallet;
//                           auth.setUserWallet(updatedWallet);
//                           if (sheetContext.mounted) Navigator.pop(sheetContext);
//                           if (mounted) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                   "₹${amount.toStringAsFixed(0)} added to your "
//                                       "offline wallet.",
//                                 ),
//                               ),
//                             );
//                           }
//                         } else {
//                           if (sheetContext.mounted) {
//                             ScaffoldMessenger.of(sheetContext).showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                   result["message"]?.toString() ?? "Recharge failed",
//                                 ),
//                               ),
//                             );
//                           }
//                         }
//                       },
//                       child: isSubmitting
//                           ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor: AlwaysStoppedAnimation(Colors.white),
//                         ),
//                       )
//                           : const Text(
//                         "Recharge",
//                         style: TextStyle(
//                             color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _openPhotoViewer() {
//     Navigator.of(context).push(
//       PageRouteBuilder(
//         opaque: false,
//         barrierColor: Colors.black,
//         pageBuilder: (_, __, ___) => _PhotoViewerScreen(image: _profileImage!),
//         transitionsBuilder: (_, animation, __, child) =>
//             FadeTransition(opacity: animation, child: child),
//       ),
//     );
//   }
//
//   void _copyToClipboard(String value, String label) {
//     Clipboard.setData(ClipboardData(text: value));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("$label copied"), duration: const Duration(seconds: 1)),
//     );
//   }
//
//   // ── Bottom sheets ────────────────────────────────────────────────────
//
//   void _showImageSourceSheet(AppColors c) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: c.surface,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const SizedBox(height: 8),
//             Container(
//               width: 36,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: c.border,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 16),
//               child: Text(
//                 "Change photo",
//                 style: TextStyle(
//                     fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
//               ),
//             ),
//             _sheetOption(
//               c: c,
//               icon: Icons.photo_library_outlined,
//               label: "Choose from gallery",
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.gallery);
//               },
//             ),
//             _sheetOption(
//               c: c,
//               icon: Icons.camera_alt_outlined,
//               label: "Take a photo",
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.camera);
//               },
//             ),
//             if (_profileImage != null)
//               _sheetOption(
//                 c: c,
//                 icon: Icons.delete_outline_rounded,
//                 label: "Remove photo",
//                 color: c.dangerText,
//                 onTap: () {
//                   Navigator.pop(context);
//                   _removeImage();
//                 },
//               ),
//             const SizedBox(height: 8),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _openQrScreen(AppColors c, String qrValue, String userName, String userId) {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => _QrCodeScreen(
//           screenshotController: _screenshotController,
//           profileImage: _profileImage,
//           userName: userName,
//           userId: userId,
//           qrValue: qrValue,
//           onShare: _handleShare,
//         ),
//       ),
//     );
//   }
//
//   void _showAccountInfoSheet(
//       AppColors c, String userName, String userEmail, String userId, String memberSince) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: c.surface,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) => SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 36,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: c.border,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 child: Text(
//                   "Account details",
//                   style: TextStyle(
//                       fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
//                 ),
//               ),
//               _infoRow(c, "User name", userName),
//               _infoDivider(c),
//               _infoRow(c, "Email", userEmail.isNotEmpty ? userEmail : "—"),
//               _infoDivider(c),
//               _infoRow(c, "User ID", userId.isNotEmpty ? userId : "—"),
//               _infoDivider(c),
//               _infoRow(c, "Member since", memberSince),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _sheetOption({
//     required AppColors c,
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     Color? color,
//   }) {
//     final effectiveColor = color ?? c.textPrimary;
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
//         child: Row(
//           children: [
//             Icon(icon, color: effectiveColor, size: 20),
//             const SizedBox(width: 14),
//             Text(
//               label,
//               style: TextStyle(
//                   fontSize: 14, fontWeight: FontWeight.w500, color: effectiveColor),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Build ────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final theme = context.watch<ThemeProvider>();
//     final c = AppColors(isDark: theme.isDark);
//
//     if (!auth.hydrated) {
//       return Scaffold(
//         backgroundColor: c.bg,
//         body: Center(child: CircularProgressIndicator(color: c.purple)),
//       );
//     }
//
//     final user = auth.user;
//     final userId = user?.id ?? "";
//     final userName = user?.name.isNotEmpty == true ? user!.name : "User";
//     final userEmail = user?.email ?? "";
//
//     final initials = userName
//         .split(" ")
//         .where((n) => n.isNotEmpty)
//         .map((n) => n[0])
//         .join("")
//         .toUpperCase();
//     final initialsShort = initials.length > 2 ? initials.substring(0, 2) : initials;
//
//     final qrValue = jsonEncode({"userId": userId, "receiverName": userName});
//     final walletBalance = user?.wallet?.balance ?? 0;
//     final lockedBalance = user?.wallet?.lockedBalance ?? 0;
//
//     String memberSince = "—";
//     final createdAt = user?.extra['created_at'];
//     if (createdAt != null) {
//       try {
//         final date = DateTime.parse(createdAt.toString());
//         const months = [
//           "Jan", "Feb", "Mar", "Apr", "May", "Jun",
//           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
//         ];
//         memberSince = "${months[date.month - 1]} ${date.year}";
//       } catch (_) {}
//     }
//
//     return Scaffold(
//       backgroundColor: c.bg,
//       body: Stack(
//         children: [
//           // ── HERO BACKGROUND ─────────────────────────────────────────
//           Container(
//             height: 300,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   c.purple.withOpacity(0.55),
//                   c.purple.withOpacity(0.18),
//                   c.bg,
//                 ],
//               ),
//             ),
//             child: Stack(
//               clipBehavior: Clip.none,
//               children: [
//                 Positioned(
//                   top: -40,
//                   right: -30,
//                   child: Container(
//                     width: 160,
//                     height: 160,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.white.withOpacity(0.05),
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 60,
//                   left: -50,
//                   child: Container(
//                     width: 120,
//                     height: 120,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.white.withOpacity(0.04),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // ── HIDDEN SHARE CAPTURE TARGET ───────────────────────────────
//           // IMPORTANT: do not use Offstage here. Offstage widgets are not
//           // painted, so RenderRepaintBoundary.toImage() has nothing reliable
//           // to capture. This target stays mounted and painted just outside
//           // the visible viewport.
//           Positioned(
//             left: -1000,
//             top: 0,
//             child: RepaintBoundary(
//               key: _shareCaptureKey,
//               child: Material(
//                 color: Colors.white,
//                 child: SizedBox(
//                   width: 320,
//                   child: Container(
//                     padding: const EdgeInsets.all(24),
//                     color: Colors.white,
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               width: 40,
//                               height: 40,
//                               decoration: const BoxDecoration(
//                                 color: Color(0xFF534AB7),
//                                 shape: BoxShape.circle,
//                               ),
//                               clipBehavior: Clip.antiAlias,
//                               child: _profileImage != null
//                                   ? Image.file(
//                                       _profileImage!,
//                                       fit: BoxFit.cover,
//                                     )
//                                   : Center(
//                                       child: Text(
//                                         initialsShort,
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w600,
//                                         ),
//                                       ),
//                                     ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Text(
//                                 userName,
//                                 style: const TextStyle(
//                                   color: Color(0xFF1A1A1A),
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         QrImageView(
//                           data: qrValue.isNotEmpty ? qrValue : "empty",
//                           size: 220,
//                           backgroundColor: Colors.white,
//                           eyeStyle: const QrEyeStyle(
//                             color: Color(0xFF1A1A1A),
//                           ),
//                           dataModuleStyle: const QrDataModuleStyle(
//                             color: Color(0xFF1A1A1A),
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         const Text(
//                           "Scan to pay with NextPay app",
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Color(0xFF6B6B6B),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // ── FOREGROUND CONTENT ───────────────────────────────────────
//           SafeArea(
//             child: Column(
//               children: [
//                 // Top bar
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       GestureDetector(
//                         onTap: () => Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(builder: (_) => const HomeScreen()),
//                         ),
//                         child: Container(
//                           width: 38,
//                           height: 38,
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.10),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: const Icon(Icons.arrow_back_rounded,
//                               color: Colors.white, size: 20),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Name + avatar row
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               userName,
//                               style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w700),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             const SizedBox(height: 10),
//                             Text(
//                               "User ID",
//                               style: TextStyle(
//                                   color: Colors.white.withOpacity(0.6), fontSize: 12),
//                             ),
//                             const SizedBox(height: 4),
//                             GestureDetector(
//                               onTap: userId.isNotEmpty
//                                   ? () => _copyToClipboard(userId, "User ID")
//                                   : null,
//                               child: Row(
//                                 children: [
//                                   Flexible(
//                                     child: Text(
//                                       userId.isNotEmpty ? userId : "—",
//                                       style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 15,
//                                           fontWeight: FontWeight.w600),
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                   if (userId.isNotEmpty) ...[
//                                     const SizedBox(width: 6),
//                                     Icon(Icons.copy_rounded,
//                                         size: 14, color: Colors.white.withOpacity(0.6)),
//                                   ],
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Stack(
//                         clipBehavior: Clip.none,
//                         children: [
//                           GestureDetector(
//                             onTap: _profileImage != null
//                                 ? _openPhotoViewer
//                                 : () => _showImageSourceSheet(c),
//                             child: Container(
//                               width: 76,
//                               height: 76,
//                               decoration: BoxDecoration(
//                                 color: c.purple,
//                                 shape: BoxShape.circle,
//                                 border: Border.all(color: Colors.white, width: 2),
//                               ),
//                               clipBehavior: Clip.antiAlias,
//                               child: _profileImage != null
//                                   ? Image.file(_profileImage!,
//                                   fit: BoxFit.cover, width: 76, height: 76)
//                                   : Center(
//                                 child: Text(
//                                   initialsShort,
//                                   style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.w600),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           Positioned(
//                             bottom: -2,
//                             right: -2,
//                             child: GestureDetector(
//                               onTap: () => _showImageSourceSheet(c),
//                               child: Container(
//                                 width: 26,
//                                 height: 26,
//                                 decoration: BoxDecoration(
//                                   color: c.purple,
//                                   shape: BoxShape.circle,
//                                   border: Border.all(color: c.bg, width: 2),
//                                 ),
//                                 child: const Icon(Icons.camera_alt_rounded,
//                                     color: Colors.white, size: 12),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 22),
//
//                 // Scrollable content on solid background
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.only(bottom: 32),
//                     child: Column(
//                       children: [
//                         // ── QUICK STAT PILLS ─────────────────────────
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16),
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: _pillCard(
//                                   c: c,
//                                   color: c.purpleLight,
//                                   textColor: c.purpleDark,
//                                   icon: Icons.account_balance_wallet_rounded,
//                                   title: "₹${walletBalance.toStringAsFixed(0)}",
//                                   subtitle: "Wallet balance",
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: _pillCard(
//                                   c: c,
//                                   color: c.surface,
//                                   textColor: c.textPrimary,
//                                   icon: Icons.lock_clock_rounded,
//                                   title: "₹${lockedBalance.toStringAsFixed(0)}",
//                                   subtitle: "Locked balance",
//                                   bordered: true,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         const SizedBox(height: 20),
//
//                         // ── ACTION LIST ───────────────────────────────
//                         Container(
//                           margin: const EdgeInsets.symmetric(horizontal: 16),
//                           decoration: BoxDecoration(
//                             color: c.surface,
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(color: c.border, width: 1),
//                           ),
//                           child: Column(
//                             children: [
//                               _listRow(
//                                 c: c,
//                                 icon: Icons.qr_code_2_rounded,
//                                 title: "Your QR code",
//                                 subtitle: "Use to receive money from any UPI app",
//                                 onTap: () => _openQrScreen(c, qrValue, userName, userId),
//                               ),
//                               _infoDivider(c),
//                               _listRow(
//                                 c: c,
//                                 icon: Icons.badge_outlined,
//                                 title: "Account details",
//                                 subtitle: "Name, email, member since",
//                                 onTap: () => _showAccountInfoSheet(
//                                     c, userName, userEmail, userId, memberSince),
//                               ),
//                               _infoDivider(c),
//                               _listRow(
//                                 c: c,
//                                 icon: Icons.ios_share_rounded,
//                                 title: "Share QR code",
//                                 subtitle: "Send your code to someone",
//                                 onTap: _handleShare,
//                               ),
//                               _infoDivider(c),
//                               _listRow(
//                                 c: c,
//                                 icon: Icons.savings_outlined,
//                                 title: "Offline wallet",
//                                 subtitle: "Recharge to spend money without internet",
//                                 onTap: () => _showOfflineWalletSheet(c),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         const SizedBox(height: 20),
//
//                         // ── LOGOUT ─────────────────────────────────────
//                         Container(
//                           margin: const EdgeInsets.symmetric(horizontal: 16),
//                           decoration: BoxDecoration(
//                             color: c.dangerBg,
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                           child: Material(
//                             color: Colors.transparent,
//                             borderRadius: BorderRadius.circular(16),
//                             child: InkWell(
//                               borderRadius: BorderRadius.circular(16),
//                               onTap: _handleLogout,
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 16),
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Icon(Icons.logout_rounded,
//                                         size: 18, color: c.dangerText),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       "Log out",
//                                       style: TextStyle(
//                                           color: c.dangerText,
//                                           fontWeight: FontWeight.w600,
//                                           fontSize: 14),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(height: 20),
//                         Text(
//                           "© 2025 Built by moinworksonlocalhost",
//                           style: TextStyle(fontSize: 11, color: c.textSecondary),
//                         ),
//                         const SizedBox(height: 12),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _pillCard({
//     required AppColors c,
//     required Color color,
//     required Color textColor,
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     bool bordered = false,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
//       decoration: BoxDecoration(
//         color: color,
//         borderRadius: BorderRadius.circular(18),
//         border: bordered ? Border.all(color: c.border, width: 1) : null,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: textColor, size: 20),
//           const SizedBox(height: 10),
//           Text(
//             title,
//             style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _listRow({
//     required AppColors c,
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
//         child: Row(
//           children: [
//             Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 color: c.purpleLight,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Icon(icon, color: c.purpleDark, size: 20),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: TextStyle(
//                         fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     subtitle,
//                     style: TextStyle(fontSize: 12, color: c.textSecondary),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _infoRow(AppColors c, String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
//           Flexible(
//             child: Text(
//               value,
//               textAlign: TextAlign.right,
//               style: TextStyle(
//                   fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _infoDivider(AppColors c) {
//     return Container(
//         height: 1, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 18));
//   }
// }
//
// // ── Full-screen photo viewer ─────────────────────────────────────────────
//
// class _PhotoViewerScreen extends StatelessWidget {
//   final File image;
//   const _PhotoViewerScreen({required this.image});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Center(
//             child: InteractiveViewer(
//               minScale: 0.5,
//               maxScale: 4.0,
//               child: Image.file(image, fit: BoxFit.contain),
//             ),
//           ),
//           Positioned(
//             top: MediaQuery.of(context).padding.top + 12,
//             left: 16,
//             child: GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.15),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: MediaQuery.of(context).padding.bottom + 24,
//             left: 0,
//             right: 0,
//             child: const Text(
//               "Your photo",
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.white54, fontSize: 12),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Full-screen QR code view ─────────────────────────────────────────────
//
// class _QrCodeScreen extends StatelessWidget {
//   final ScreenshotController screenshotController;
//   final File? profileImage;
//   final String userName;
//   final String userId;
//   final String qrValue;
//   final VoidCallback onShare;
//
//   const _QrCodeScreen({
//     required this.screenshotController,
//     required this.profileImage,
//     required this.userName,
//     required this.userId,
//     required this.qrValue,
//     required this.onShare,
//   });
//
//   Future<void> _handleDownload(BuildContext context) async {
//     try {
//       final imageBytes = await screenshotController.capture();
//       if (imageBytes == null) {
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Couldn't capture QR code")),
//           );
//         }
//         return;
//       }
//
//       // getApplicationDocumentsDirectory() is the app's PRIVATE sandbox —
//       // it never shows up in Photos/Gallery/Files, which is why the old
//       // code showed "QR code saved" but the file was never visible to the
//       // user. We need to write into the device's public media store.
//       final hasAccess = await Gal.hasAccess();
//       if (!hasAccess) {
//         final granted = await Gal.requestAccess();
//         if (!granted) {
//           if (context.mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text(
//                   "Storage/Photos permission is needed to save the QR code",
//                 ),
//               ),
//             );
//           }
//           return;
//         }
//       }
//
//       // Write to a temp file first (Gal.putImage needs a file path), then
//       // hand it off to the gallery.
//       final tempDir = await getTemporaryDirectory();
//       final tempFile = File(
//         '${tempDir.path}/nextpay_qr_${DateTime.now().millisecondsSinceEpoch}.png',
//       );
//       await tempFile.writeAsBytes(imageBytes);
//
//       await Gal.putImage(tempFile.path, album: "NextPay");
//
//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("QR code saved to gallery"),
//           duration: Duration(seconds: 2),
//         ),
//       );
//     } on GalException catch (e) {
//       debugPrint("Gal save error: ${e.type} ${e.platformException}");
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Couldn't save QR code to gallery")),
//         );
//       }
//     } catch (e) {
//       debugPrint("Download error: $e");
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Couldn't save QR code")),
//         );
//       }
//     }
//   }
//
//   void _copyId(BuildContext context) {
//     Clipboard.setData(ClipboardData(text: userId));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("User ID copied"), duration: Duration(seconds: 1)),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = context.watch<ThemeProvider>();
//     final c = AppColors(isDark: theme.isDark);
//     const qrFg = Color(0xFF1A1A1A);
//
//     final initials = userName
//         .split(" ")
//         .where((n) => n.isNotEmpty)
//         .map((n) => n[0])
//         .join("")
//         .toUpperCase();
//     final initialsShort = initials.length > 2 ? initials.substring(0, 2) : initials;
//
//     return Scaffold(
//       backgroundColor: c.bg,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Top bar
//             Padding(
//               padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   IconButton(
//                     onPressed: () => Navigator.pop(context),
//                     icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
//                   ),
//                   Row(
//                     children: [
//                       IconButton(
//                         onPressed: () => _handleDownload(context),
//                         icon: Icon(Icons.download_rounded, color: c.textPrimary),
//                       ),
//                       IconButton(
//                         onPressed: onShare,
//                         icon: Icon(Icons.more_vert_rounded, color: c.textPrimary),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
//                 child: Column(
//                   children: [
//                     // ── QR CARD ─────────────────────────────────────
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
//                       decoration: BoxDecoration(
//                         color: c.surface,
//                         borderRadius: BorderRadius.circular(24),
//                         border: Border.all(color: c.border, width: 1),
//                       ),
//                       child: Column(
//                         children: [
//                           Row(
//                             children: [
//                               Container(
//                                 width: 44,
//                                 height: 44,
//                                 decoration: BoxDecoration(
//                                   color: c.purple,
//                                   shape: BoxShape.circle,
//                                 ),
//                                 clipBehavior: Clip.antiAlias,
//                                 child: profileImage != null
//                                     ? Image.file(profileImage!, fit: BoxFit.cover)
//                                     : Center(
//                                   child: Text(
//                                     initialsShort,
//                                     style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 15,
//                                         fontWeight: FontWeight.w600),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 14),
//                               Expanded(
//                                 child: Text(
//                                   userName,
//                                   style: TextStyle(
//                                       color: c.textPrimary,
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.w600),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 24),
//                           Screenshot(
//                             controller: screenshotController,
//                             child: Container(
//                               padding: const EdgeInsets.all(16),
//                               color: Colors.white,
//                               child: Stack(
//                                 alignment: Alignment.center,
//                                 children: [
//                                   QrImageView(
//                                     data: qrValue.isNotEmpty ? qrValue : "empty",
//                                     size: 220,
//                                     backgroundColor: Colors.white,
//                                     eyeStyle: const QrEyeStyle(color: qrFg),
//                                     dataModuleStyle: const QrDataModuleStyle(color: qrFg),
//                                   ),
//                                   Container(
//                                     width: 36,
//                                     height: 36,
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       shape: BoxShape.rectangle,
//                                       border: Border.all(color: c.border, width: 1),
//                                     ),
//                                     child: Center(
//                                       child: ClipRect(
//                                         child: Container(
//                                           width: 30,
//                                           height: 30,
//                                           color: c.purple,
//                                           child: Image.asset(
//                                             'assets/icon/app_icon.png',
//                                             fit: BoxFit.fitWidth,
//                                             errorBuilder: (_, __, ___) => const Icon(
//                                               Icons.bolt_outlined,
//                                               color: Colors.white,
//                                               size: 10,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 20),
//                           Text(
//                             "Scan to pay with ZeroBars app",
//                             style: TextStyle(fontSize: 13, color: c.textSecondary),
//                           ),
//                           const SizedBox(height: 20),
//                           Container(height: 1, color: c.border),
//                           const SizedBox(height: 16),
//                           GestureDetector(
//                             onTap: userId.isNotEmpty ? () => _copyId(context) : null,
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Flexible(
//                                   child: Text(
//                                     "User ID: $userId",
//                                     style: TextStyle(
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w600,
//                                         color: c.textPrimary),
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                                 if (userId.isNotEmpty) ...[
//                                   const SizedBox(width: 8),
//                                   Icon(Icons.copy_rounded, size: 15, color: c.textSecondary),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 28),
//
//                     // ── SHARE BUTTON ───────────────────────────────────
//                     SizedBox(
//                       width: double.infinity,
//                       child: DecoratedBox(
//                         decoration: BoxDecoration(
//                           color: c.purpleLight,
//                           borderRadius: BorderRadius.circular(28),
//                         ),
//                         child: Material(
//                           color: Colors.transparent,
//                           borderRadius: BorderRadius.circular(28),
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(28),
//                             onTap: onShare,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.ios_share_rounded,
//                                       color: c.purpleDark, size: 18),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     "Share QR code",
//                                     style: TextStyle(
//                                         color: c.purpleDark,
//                                         fontWeight: FontWeight.w700,
//                                         fontSize: 15),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     // ── SCANNER BUTTON (hook up to your scan screen) ───
//                     SizedBox(
//                       width: double.infinity,
//                       child: OutlinedButton(
//                         onPressed: () {
//                           Navigator.of(context).push(
//                             MaterialPageRoute(builder: (_) => const ScannerScreen()),
//                           );
//                         },
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           side: BorderSide(color: c.border),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(28),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.qr_code_scanner_rounded,
//                                 color: c.textPrimary, size: 18),
//                             const SizedBox(width: 8),
//                             Text(
//                               "Open scanner",
//                               style: TextStyle(
//                                   color: c.textPrimary,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 15),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 28),
//                     Text(
//                       "Powered by ZeroBars",
//                       style: TextStyle(fontSize: 11, color: c.textSecondary),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:zerobars/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gal/gal.dart';
import 'dart:convert';
import '../services/offline_wallet_service.dart';
import '../services/app_lock_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../models/wallet.dart';
import 'home_screen.dart';
import 'scanner_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  // Dedicated controller backed by an always-mounted (offstage) widget so
  // "Share QR code" works from the profile list row too, not only from
  // inside the full-screen QR viewer where a Screenshot widget happens
  // to be on screen.
  final GlobalKey _shareCaptureKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;

  // Biometric lock state
  bool _biometricEnabled = false;
  bool _bioSupported = false;
  bool _bioBusy = false;

  // FIX: this used to be one fixed key ('profile_image_path') and one fixed
  // filename ('profile_photo.jpg') shared by every account on the device.
  // Whoever logged in last would overwrite the same file, so a new account
  // on the same device would see the previous account's photo (or vice
  // versa). Both the pref key AND the file on disk are now namespaced by
  // the current user's id — this key format matches HomeScreen's
  // `_profileImageKey`, since both screens must agree on where the photo
  // for a given account lives.
  String _profileImageKey(String userId) => 'profile_image_path_$userId';

  String? _resolveUserId() {
    final id = context.read<AuthProvider>().user?.id;
    return (id != null && id.isNotEmpty) ? id : null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedImage();
    _loadBiometricState();
  }

  // ── Biometric lock ───────────────────────────────────────────────────────

  Future<void> _loadBiometricState() async {
    final enabled = await AppLockService.instance.isBiometricEnabled();
    final supported = await AppLockService.instance.canUseBiometrics();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _bioSupported = supported;
      });
    }
  }

  Future<void> _toggleBiometric(bool turnOn) async {
    if (_bioBusy) return;
    setState(() => _bioBusy = true);

    if (turnOn) {
      if (!_bioSupported) {
        setState(() => _bioBusy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Your device doesn't support biometrics, or none are enrolled."),
            ),
          );
        }
        return;
      }
      // Confirm it actually works before flipping the setting on.
      final ok = await AppLockService.instance.authenticateWithBiometrics();
      if (!mounted) return;
      if (ok) {
        await AppLockService.instance.setBiometricEnabled(true);
        if (mounted) {
          setState(() {
            _biometricEnabled = true;
            _bioBusy = false;
          });
        }
      } else {
        setState(() => _bioBusy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't verify biometrics — try again.")),
          );
        }
      }
    } else {
      // Reset: confirm before turning off so it isn't a mis-tap, and so it
      // still works even if biometrics are currently broken on the device.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Turn off biometric unlock?"),
          content: const Text("You'll use your PIN to unlock the app instead."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Turn off"),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await AppLockService.instance.setBiometricEnabled(false);
        if (mounted) setState(() => _biometricEnabled = false);
      }
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  // ── Persistence / image handling ────────────────────────────────────────

  Future<void> _loadSavedImage() async {
    final userId = _resolveUserId();
    if (userId == null) {
      if (mounted) setState(() => _profileImage = null);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profileImageKey(userId));
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        if (mounted) setState(() => _profileImage = file);
      } else {
        await prefs.remove(_profileImageKey(userId));
        if (mounted) setState(() => _profileImage = null);
      }
    } else {
      if (mounted) setState(() => _profileImage = null);
    }
  }

  Future<void> _saveImagePath(String userId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey(userId), path);
  }

  Future<void> _clearImagePath(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileImageKey(userId));
  }

  Future<File> _persistImage(String userId, File tempFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    // Per-user filename — this is the part the earlier fix in HomeScreen
    // was still missing. Even with a per-user pref key, every account was
    // still writing to the same physical file ('profile_photo.jpg'), so
    // the file's contents got overwritten by whichever account uploaded a
    // photo most recently, corrupting the "old" account's saved path too.
    final permanent = File('${appDir.path}/profile_photo_$userId.jpg');
    return tempFile.copy(permanent.path);
  }

  Future<void> _handleShare() async {
    try {
      // The share target is always mounted in the widget tree. Capture its
      // RepaintBoundary directly instead of using ScreenshotController.
      final boundaryContext = _shareCaptureKey.currentContext;

      if (boundaryContext == null) {
        debugPrint("QR share target is not mounted");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't prepare QR code to share"),
            ),
          );
        }
        return;
      }

      final renderObject = boundaryContext.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        debugPrint(
          "QR share target is not a RenderRepaintBoundary: "
              "${renderObject.runtimeType}",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't prepare QR code to share"),
            ),
          );
        }
        return;
      }

      final boundary = renderObject;

      // Make sure Flutter has painted the target before calling toImage().
      await WidgetsBinding.instance.endOfFrame;

      if (boundary.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await WidgetsBinding.instance.endOfFrame;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      image.dispose();

      if (byteData == null) {
        debugPrint("Failed to convert QR image to PNG bytes");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't prepare QR code to share"),
            ),
          );
        }
        return;
      }

      final imageBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();

      final file = File(
        '${dir.path}/zerobars_qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(imageBytes, flush: true);

      if (!await file.exists()) {
        throw Exception("QR share file was not created");
      }

      if (!mounted) return;

      final size = MediaQuery.of(context).size;

      final result = await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'image/png',
            name: 'zerobars_qr.png',
          ),
        ],
        text: 'Scan to pay me on ZeroBars',
        sharePositionOrigin: Rect.fromCenter(
          center: Offset(
            size.width / 2,
            size.height * 0.75,
          ),
          width: 200,
          height: 50,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        debugPrint("Share sheet dismissed by user");
      }
    } catch (e, stackTrace) {
      debugPrint("QR Share error: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't share QR code. Try again."),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final userId = _resolveUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in again to set a photo")),
        );
      }
      return;
    }
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      final permanent = await _persistImage(userId, File(picked.path));
      await _saveImagePath(userId, permanent.path);
      if (mounted) setState(() => _profileImage = permanent);
    } catch (e) {
      debugPrint("Image pick error: $e");
    }
  }

  Future<void> _removeImage() async {
    final userId = _resolveUserId();
    if (_profileImage != null) {
      try {
        if (await _profileImage!.exists()) await _profileImage!.delete();
      } catch (_) {}
    }
    if (userId != null) {
      await _clearImagePath(userId);
    }
    if (mounted) setState(() => _profileImage = null);
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthProvider>();

    final hasLockedBalance = (auth.user?.wallet?.lockedBalance ?? 0) > 0;

    final prefs = await SharedPreferences.getInstance();
    final key = "pending_transactions_${auth.user?.id}";
    final pending = prefs.getStringList(key) ?? [];
    final hasPendingTransactions = pending.isNotEmpty;

    if (hasLockedBalance || hasPendingTransactions) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please sync all offline payments before logging out."),
        ),
      );
      return;
    }

    await auth.logout();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Offline wallet recharge ──────────────────────────────────────────

  Future<void> _showOfflineWalletSheet(AppColors c) async {
    final auth = context.read<AuthProvider>();
    final wallet = auth.user?.wallet;
    if (wallet == null) return;

    final availableBalance =
    (wallet.balance - wallet.lockedBalance).clamp(0, wallet.balance);
    final controller = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    "Offline wallet",
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Recharge it from your main balance to spend offline. "
                        "This is a real transaction — the amount is debited "
                        "from your balance right now, so it's never lost or "
                        "duplicated even if this device is lost before you sync.",
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Offline wallet balance",
                                style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              "₹${wallet.offlineBalance.toStringAsFixed(0)}",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Main balance",
                                style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              "₹${availableBalance.toStringAsFixed(0)}",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: TextStyle(color: c.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      hintText: "Amount to recharge, e.g. 100",
                      filled: true,
                      fillColor: c.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                        final amount = num.tryParse(controller.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text("Enter a valid amount")),
                          );
                          return;
                        }
                        if (amount > availableBalance) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                "You only have ₹${availableBalance.toStringAsFixed(0)} "
                                    "in your main balance.",
                              ),
                            ),
                          );
                          return;
                        }

                        setSheetState(() => isSubmitting = true);

                        // This is the actual server call — main balance is
                        // debited and offline_balance is credited
                        // atomically, right now, while we're online.
                        final result = await OfflineWalletService.recharge(amount);

                        setSheetState(() => isSubmitting = false);

                        if (result["success"] == true) {
                          final updatedWallet = result["wallet"] as Wallet;
                          auth.setUserWallet(updatedWallet);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "₹${amount.toStringAsFixed(0)} added to your "
                                      "offline wallet.",
                                ),
                              ),
                            );
                          }
                        } else {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result["message"]?.toString() ?? "Recharge failed",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : const Text(
                        "Recharge",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPhotoViewer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _PhotoViewerScreen(image: _profileImage!),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$label copied"), duration: const Duration(seconds: 1)),
    );
  }

  // ── Bottom sheets ────────────────────────────────────────────────────

  void _showImageSourceSheet(AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Change photo",
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
            _sheetOption(
              c: c,
              icon: Icons.photo_library_outlined,
              label: "Choose from gallery",
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            _sheetOption(
              c: c,
              icon: Icons.camera_alt_outlined,
              label: "Take a photo",
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_profileImage != null)
              _sheetOption(
                c: c,
                icon: Icons.delete_outline_rounded,
                label: "Remove photo",
                color: c.dangerText,
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openQrScreen(AppColors c, String qrValue, String userName, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QrCodeScreen(
          screenshotController: _screenshotController,
          profileImage: _profileImage,
          userName: userName,
          userId: userId,
          qrValue: qrValue,
          onShare: _handleShare,
        ),
      ),
    );
  }

  void _showAccountInfoSheet(
      AppColors c, String userName, String userEmail, String userId, String memberSince) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Account details",
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              _infoRow(c, "User name", userName),
              _infoDivider(c),
              _infoRow(c, "Email", userEmail.isNotEmpty ? userEmail : "—"),
              _infoDivider(c),
              _infoRow(c, "User ID", userId.isNotEmpty ? userId : "—"),
              _infoDivider(c),
              _infoRow(c, "Member since", memberSince),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required AppColors c,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: effectiveColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    if (!auth.hydrated) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.purple)),
      );
    }

    final user = auth.user;
    final userId = user?.id ?? "";
    final userName = user?.name.isNotEmpty == true ? user!.name : "User";
    final userEmail = user?.email ?? "";

    final initials = userName
        .split(" ")
        .where((n) => n.isNotEmpty)
        .map((n) => n[0])
        .join("")
        .toUpperCase();
    final initialsShort = initials.length > 2 ? initials.substring(0, 2) : initials;

    final qrValue = jsonEncode({"userId": userId, "receiverName": userName});
    final walletBalance = user?.wallet?.balance ?? 0;
    final lockedBalance = user?.wallet?.lockedBalance ?? 0;

    String memberSince = "—";
    final createdAt = user?.extra['created_at'];
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt.toString());
        const months = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        memberSince = "${months[date.month - 1]} ${date.year}";
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // ── HERO BACKGROUND ─────────────────────────────────────────
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.purple.withOpacity(0.55),
                  c.purple.withOpacity(0.18),
                  c.bg,
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: -50,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── HIDDEN SHARE CAPTURE TARGET ───────────────────────────────
          // IMPORTANT: do not use Offstage here. Offstage widgets are not
          // painted, so RenderRepaintBoundary.toImage() has nothing reliable
          // to capture. This target stays mounted and painted just outside
          // the visible viewport.
          Positioned(
            left: -1000,
            top: 0,
            child: RepaintBoundary(
              key: _shareCaptureKey,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 320,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF534AB7),
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _profileImage != null
                                  ? Image.file(
                                _profileImage!,
                                fit: BoxFit.cover,
                              )
                                  : Center(
                                child: Text(
                                  initialsShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: qrValue.isNotEmpty ? qrValue : "empty",
                          size: 220,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            color: Color(0xFF1A1A1A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Scan to pay with ZeroBars app",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── FOREGROUND CONTENT ───────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // Name + avatar row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "User ID",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: userId.isNotEmpty
                                  ? () => _copyToClipboard(userId, "User ID")
                                  : null,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userId.isNotEmpty ? userId : "—",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (userId.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.copy_rounded,
                                        size: 14, color: Colors.white.withOpacity(0.6)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: _profileImage != null
                                ? _openPhotoViewer
                                : () => _showImageSourceSheet(c),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: c.purple,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _profileImage != null
                                  ? Image.file(_profileImage!,
                                  fit: BoxFit.cover, width: 76, height: 76)
                                  : Center(
                                child: Text(
                                  initialsShort,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: () => _showImageSourceSheet(c),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c.purple,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.bg, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Scrollable content on solid background
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        // ── QUICK STAT PILLS ─────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _pillCard(
                                  c: c,
                                  color: c.purpleLight,
                                  textColor: c.purpleDark,
                                  icon: Icons.account_balance_wallet_rounded,
                                  title: "₹${walletBalance.toStringAsFixed(0)}",
                                  subtitle: "Wallet balance",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _pillCard(
                                  c: c,
                                  color: c.surface,
                                  textColor: c.textPrimary,
                                  icon: Icons.lock_clock_rounded,
                                  title: "₹${lockedBalance.toStringAsFixed(0)}",
                                  subtitle: "Locked balance",
                                  bordered: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── ACTION LIST ───────────────────────────────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.border, width: 1),
                          ),
                          child: Column(
                            children: [
                              _listRow(
                                c: c,
                                icon: Icons.qr_code_2_rounded,
                                title: "Your QR code",
                                subtitle: "Use to receive money from any UPI app",
                                onTap: () => _openQrScreen(c, qrValue, userName, userId),
                              ),
                              _infoDivider(c),
                              _listRow(
                                c: c,
                                icon: Icons.badge_outlined,
                                title: "Account details",
                                subtitle: "Name, email, member since",
                                onTap: () => _showAccountInfoSheet(
                                    c, userName, userEmail, userId, memberSince),
                              ),
                              _infoDivider(c),
                              _listRow(
                                c: c,
                                icon: Icons.ios_share_rounded,
                                title: "Share QR code",
                                subtitle: "Send your code to someone",
                                onTap: _handleShare,
                              ),
                              _infoDivider(c),
                              _listRow(
                                c: c,
                                icon: Icons.savings_outlined,
                                title: "Offline wallet",
                                subtitle: "Recharge to spend money without internet",
                                onTap: () => _showOfflineWalletSheet(c),
                              ),
                              _infoDivider(c),
                              _biometricRow(c),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── LOGOUT ─────────────────────────────────────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.dangerBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _handleLogout,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        size: 18, color: c.dangerText),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Log out",
                                      style: TextStyle(
                                          color: c.dangerText,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text(
                          "© 2025 Built by moinworksonlocalhost",
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillCard({
    required AppColors c,
    required Color color,
    required Color textColor,
    required IconData icon,
    required String title,
    required String subtitle,
    bool bordered = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: bordered ? Border.all(color: c.border, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _listRow({
    required AppColors c,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.purpleLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c.purpleDark, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _biometricRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.purpleLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fingerprint, color: c.purpleDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Biometric lock",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _bioSupported
                      ? "Use Face ID / fingerprint to unlock"
                      : "Not available on this device",
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          _bioBusy
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.purple),
          )
              : Switch(
            value: _biometricEnabled,
            onChanged: _bioSupported ? _toggleBiometric : null,
            activeColor: c.purple,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(AppColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider(AppColors c) {
    return Container(
        height: 1, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 18));
  }
}

// ── Full-screen photo viewer ─────────────────────────────────────────────

class _PhotoViewerScreen extends StatelessWidget {
  final File image;
  const _PhotoViewerScreen({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(image, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: const Text(
              "Your photo",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen QR code view ─────────────────────────────────────────────

class _QrCodeScreen extends StatelessWidget {
  final ScreenshotController screenshotController;
  final File? profileImage;
  final String userName;
  final String userId;
  final String qrValue;
  final VoidCallback onShare;

  const _QrCodeScreen({
    required this.screenshotController,
    required this.profileImage,
    required this.userName,
    required this.userId,
    required this.qrValue,
    required this.onShare,
  });

  Future<void> _handleDownload(BuildContext context) async {
    try {
      final imageBytes = await screenshotController.capture();
      if (imageBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't capture QR code")),
          );
        }
        return;
      }

      // getApplicationDocumentsDirectory() is the app's PRIVATE sandbox —
      // it never shows up in Photos/Gallery/Files, which is why the old
      // code showed "QR code saved" but the file was never visible to the
      // user. We need to write into the device's public media store.
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Storage/Photos permission is needed to save the QR code",
                ),
              ),
            );
          }
          return;
        }
      }

      // Write to a temp file first (Gal.putImage needs a file path), then
      // hand it off to the gallery.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/zerobars_qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(imageBytes);

      await Gal.putImage(tempFile.path, album: "ZeroBars");

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("QR code saved to gallery"),
          duration: Duration(seconds: 2),
        ),
      );
    } on GalException catch (e) {
      debugPrint("Gal save error: ${e.type} ${e.platformException}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save QR code to gallery")),
        );
      }
    } catch (e) {
      debugPrint("Download error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save QR code")),
        );
      }
    }
  }

  void _copyId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User ID copied"), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);
    const qrFg = Color(0xFF1A1A1A);

    final initials = userName
        .split(" ")
        .where((n) => n.isNotEmpty)
        .map((n) => n[0])
        .join("")
        .toUpperCase();
    final initialsShort = initials.length > 2 ? initials.substring(0, 2) : initials;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _handleDownload(context),
                        icon: Icon(Icons.download_rounded, color: c.textPrimary),
                      ),
                      IconButton(
                        onPressed: onShare,
                        icon: Icon(Icons.more_vert_rounded, color: c.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    // ── QR CARD ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: c.purple,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: profileImage != null
                                    ? Image.file(profileImage!, fit: BoxFit.cover)
                                    : Center(
                                  child: Text(
                                    initialsShort,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Screenshot(
                            controller: screenshotController,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: qrValue.isNotEmpty ? qrValue : "empty",
                                    size: 220,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(color: qrFg),
                                    dataModuleStyle: const QrDataModuleStyle(color: qrFg),
                                  ),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.rectangle,
                                      border: Border.all(color: c.border, width: 1),
                                    ),
                                    child: Center(
                                      child: ClipRect(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          color: c.purple,
                                          child: Image.asset(
                                            'assets/icon/app_icon_NP.png',
                                            fit: BoxFit.fitWidth,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.bolt_outlined,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Scan to pay with ZeroBars app",
                            style: TextStyle(fontSize: 13, color: c.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: c.border),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: userId.isNotEmpty ? () => _copyId(context) : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    "User ID: $userId",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (userId.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.copy_rounded, size: 15, color: c.textSecondary),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── SHARE BUTTON ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.purpleLight,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: onShare,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.ios_share_rounded,
                                      color: c.purpleDark, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Share QR code",
                                    style: TextStyle(
                                        color: c.purpleDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── SCANNER BUTTON (hook up to your scan screen) ───
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScannerScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                color: c.textPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Open scanner",
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      "Powered by ZeroBars",
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
