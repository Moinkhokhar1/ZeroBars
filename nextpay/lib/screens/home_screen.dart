// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import 'dart:async';
// import '../providers/auth_provider.dart';
// import '../providers/theme_provider.dart';
// import '../app_colors.dart';
// import '../offline/wallet_engine.dart';
// import '../offline/sync_engine.dart';
// import '../services/storage_service.dart';
// import '../services/api_service.dart';
// import '../models/wallet_transaction.dart';
// import 'profile_screen.dart';
// import 'send_screen.dart';
// import 'scanner_screen.dart';
// import 'pending_screen.dart';
// import 'history_screen.dart';
// import 'transaction_detail_screen.dart';
// import 'login_screen.dart';
// import 'dart:convert';
// import '../widgets/people_row.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   bool _isOnline = true;
//   bool _balanceVisible = false;
//   File? _profileImage;
//   String _profileImageKey(String userId) =>
//       'profile_image_path_$userId';
//
//   StreamSubscription<List<ConnectivityResult>>? _connSub;
//   final _peopleRowKey = GlobalKey<PeopleRowState>();
//
//   // Recent transactions (same underlying data/cache as HistoryScreen).
//   List<WalletTransaction> _recentTx = [];
//   bool _txLoading = true;
//
//   // Wallet/profile (balance card + greeting) initial-load state.
//   bool _walletLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       final auth = context.read<AuthProvider>();
//
//       await auth.fetchWallet();
//
//       if (!mounted) return;
//
//       await Future.wait([
//         _loadProfileImage(),
//         _loadRecentTransactions(),
//       ]);
//
//       if (mounted) {
//         setState(() => _walletLoading = false);
//       }
//     });
//     _connSub = Connectivity().onConnectivityChanged.listen((results) {
//       final online = results.any((r) => r != ConnectivityResult.none);
//       if (mounted) setState(() => _isOnline = online);
//     });
//     Connectivity().checkConnectivity().then((results) {
//       final online = results.any((r) => r != ConnectivityResult.none);
//       if (mounted) setState(() => _isOnline = online);
//     });
//   }
//
//   String? _resolveUserId(AuthProvider auth) {
//     final user = auth.user;
//     if (user == null || user.id.isEmpty) return null;
//     return user.id;
//   }
//
//   // Loads the same data HistoryScreen shows (and shares its cache key),
//   // then keeps just the most recent 5 for the home screen preview.
//   Future<void> _loadRecentTransactions() async {
//     final auth = context.read<AuthProvider>();
//     final userId = _resolveUserId(auth);
//
//     if (userId == null || userId.isEmpty) {
//       if (mounted) {
//         setState(() {
//           _recentTx = [];
//           _txLoading = false;
//         });
//       }
//       return;
//     }
//
//     final cacheKey = "cached_transactions_$userId";
//
//     try {
//       final response = await ApiService.instance.get("/wallet/transactions");
//       final List<dynamic> data = response.data;
//
//       final txs = data
//           .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
//           .toList();
//
//       await StorageService.setItem(cacheKey, jsonEncode(data));
//
//       if (mounted) {
//         setState(() {
//           _recentTx = txs.take(5).toList();
//           _txLoading = false;
//         });
//       }
//     } catch (error) {
//       debugPrint("❌ HOME RECENT TX ERROR (trying cache): $error");
//
//       try {
//         final cached = await StorageService.getItem(cacheKey);
//
//         if (cached != null) {
//           final List<dynamic> data = jsonDecode(cached);
//           final txs = data
//               .map((e) =>
//                   WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
//               .toList();
//
//           if (mounted) {
//             setState(() => _recentTx = txs.take(5).toList());
//           }
//         }
//       } catch (e) {
//         debugPrint("❌ HOME RECENT TX CACHE ERROR: $e");
//       }
//
//       if (mounted) {
//         setState(() => _txLoading = false);
//       }
//     }
//   }
//
//   Future<bool> _hasBlockingState(AuthProvider auth) async {
//     final lockedBalance = (auth.user?.wallet?.lockedBalance ?? 0).toDouble();
//     if (lockedBalance > 0) return true;
//     final userId = _resolveUserId(auth);
//
//     if (userId == null || userId.isEmpty) return false;
//     final pendingRaw =
//     await StorageService.getItem("pending_transactions_$userId");
//     if (pendingRaw != null) {
//       try {
//         final List<dynamic> pending = jsonDecode(pendingRaw);
//         if (pending.isNotEmpty) return true;
//       } catch (e) {
//         debugPrint("PENDING TX PARSE ERROR (logout check): $e");
//       }
//     }
//     return false;
//   }
//
//   Future<void> _loadProfileImage() async {
//     final auth = context.read<AuthProvider>();
//     final userId = _resolveUserId(auth);
//
//     if (userId == null || userId.isEmpty) {
//       if (mounted) {
//         setState(() => _profileImage = null);
//       }
//       return;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final path = prefs.getString(_profileImageKey(userId));
//
//     if (path == null || path.isEmpty) {
//       if (mounted) {
//         setState(() => _profileImage = null);
//       }
//       return;
//     }
//
//     final file = File(path);
//
//     if (await file.exists()) {
//       if (!mounted) return;
//
//       setState(() => _profileImage = file);
//     } else {
//       await prefs.remove(_profileImageKey(userId));
//
//       if (mounted) {
//         setState(() => _profileImage = null);
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _connSub?.cancel();
//     super.dispose();
//   }
//
//   Future<void> _handleRefresh() async {
//     final auth = context.read<AuthProvider>();
//     final results = await Connectivity().checkConnectivity();
//     final online = results.any((r) => r != ConnectivityResult.none);
//
//     // Show skeletons again while the refresh is in flight.
//     if (mounted) {
//       setState(() {
//         _walletLoading = true;
//         _txLoading = true;
//       });
//     }
//
//     await auth.fetchWallet();
//
//     await Future.wait([
//       _loadProfileImage(),
//       _loadRecentTransactions(),
//     ]);
//
//     _peopleRowKey.currentState?.refresh();
//
//     if (mounted) {
//       setState(() {
//         _isOnline = online;
//         _walletLoading = false;
//       });
//     }
//   }
//
//   Future<void> _handleSync() async {
//     final auth = context.read<AuthProvider>();
//     final walletEngine = WalletEngine(auth);
//     final syncEngine = SyncEngine(auth, walletEngine);
//     try {
//       final result = await syncEngine.syncPendingTransactions();
//       if (result["success"] == true) {
//         await StorageService.removeItem("local_wallet");
//         await Future.delayed(const Duration(milliseconds: 500));
//         await auth.fetchWallet();
//         if (mounted) _showAlert("Synced", "All transactions completed.");
//       } else {
//         if (mounted) {
//           _showAlert("Nothing to sync",
//               result["message"] ?? "No pending transactions.");
//         }
//       }
//     } catch (error) {
//       if (mounted) _showAlert("Error", "Sync failed");
//     }
//   }
//
//   Future<void> _handleLogout() async {
//     final auth = context.read<AuthProvider>();
//     final blocked = await _hasBlockingState(auth);
//     if (blocked) {
//       if (mounted) {
//         _showAlert(
//           "Cannot log out",
//           "You have a locked balance or pending offline transactions that "
//               "need to sync first. Please connect to the internet, sync, "
//               "and try again.",
//         );
//       }
//       return;
//     }
//     await auth.logout();
//     if (!mounted) return;
//     Navigator.of(context).popUntil((route) => route.isFirst);
//   }
//
//   void _showAlert(String title, String message) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _navigate(Widget screen) async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//
//     // Refresh wallet first so the current account is ready.
//     await context.read<AuthProvider>().fetchWallet();
//
//     // Then load this account's profile image.
//     await _loadProfileImage();
//
//     if (mounted) {
//       setState(() {});
//       _peopleRowKey.currentState?.refresh();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final theme = context.watch<ThemeProvider>();
//     final c = AppColors(isDark: theme.isDark);
//     final user = auth.user;
//
//     final balance = (user?.wallet?.balance ?? 0).toDouble();
//     final offlineBalance = (user?.wallet?.offlineBalance ?? 0).toDouble();
//     final lockedBalance = (user?.wallet?.lockedBalance ?? 0).toDouble();
//
//     // FIX: Main "Available balance" is no longer reduced by lockedBalance.
//     // The money reserved for a pending offline payment was already moved
//     // out of `balance` into `offlineBalance` at recharge time — it should
//     // never be subtracted from `balance` again here. That double-counting
//     // was why the home screen appeared to dip your main balance during an
//     // offline payment and then "restore" it after sync.
//     final availableBalance = balance.toStringAsFixed(2);
//
//     // FIX: This is the figure that should actually move when you spend
//     // offline — the offline pool minus whatever is currently locked
//     // (reserved) against a pending, un-synced offline transaction.
//     final offlineAvailable =
//     (offlineBalance - lockedBalance).toStringAsFixed(2);
//
//     final lockedBalanceDisplay = lockedBalance.toStringAsFixed(2);
//     final totalBalance = balance.toStringAsFixed(2);
//     final userName =
//     user?.name.isNotEmpty == true ? user!.name : "User";
//
//     final initials = userName
//         .split(" ")
//         .where((n) => n.isNotEmpty)
//         .map((n) => n[0])
//         .join("")
//         .toUpperCase();
//     final initialsShort =
//     initials.length > 2 ? initials.substring(0, 2) : initials;
//
//     const mask = "•••••";
//
//     return Scaffold(
//       backgroundColor: c.bg,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // ── HEADER ──────────────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       GestureDetector(
//                         onTap: () => _navigate(const ProfileScreen()),
//                         child: Container(
//                           width: 44,
//                           height: 44,
//                           decoration: BoxDecoration(
//                             color: c.purple,
//                             shape: BoxShape.circle,
//                           ),
//                           clipBehavior: Clip.antiAlias,
//                           child: _profileImage != null
//                               ? Image.file(_profileImage!,
//                               fit: BoxFit.cover, width: 44, height: 44)
//                               : Center(
//                             child: Text(
//                               initialsShort,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 15,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       _walletLoading
//                           ? _ShimmerWrapper(
//                         c: c,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _skeletonBox(width: 60, height: 11),
//                             const SizedBox(height: 6),
//                             _skeletonBox(width: 110, height: 15),
//                           ],
//                         ),
//                       )
//                           : Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text("Good day",
//                               style: TextStyle(
//                                   color: c.textSecondary, fontSize: 12)),
//                           Text(userName,
//                               style: TextStyle(
//                                   color: c.textPrimary,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600)),
//                         ],
//                       ),
//                     ],
//                   ),
//                   Row(
//                     children: [
//                       // Online / offline badge
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 5),
//                         decoration: BoxDecoration(
//                           color: _isOnline ? c.successBg : c.dangerBg,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 6,
//                               height: 6,
//                               decoration: BoxDecoration(
//                                 color: _isOnline
//                                     ? c.successText
//                                     : c.dangerText,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               _isOnline ? "Online" : "Offline",
//                               style: TextStyle(
//                                 color: _isOnline
//                                     ? c.successText
//                                     : c.dangerText,
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       // Dark mode toggle
//                       GestureDetector(
//                         onTap: () =>
//                             context.read<ThemeProvider>().toggle(),
//                         child: Container(
//                           width: 36,
//                           height: 36,
//                           decoration: BoxDecoration(
//                             color: c.surface,
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(color: c.border, width: 1),
//                           ),
//                           child: Icon(
//                             theme.isDark
//                                 ? Icons.light_mode_rounded
//                                 : Icons.dark_mode_rounded,
//                             size: 18,
//                             color: c.textSecondary,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//
//             Expanded(
//               child: RefreshIndicator(
//                 color: c.purple,
//                 onRefresh: _handleRefresh,
//                 child: SingleChildScrollView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   padding: const EdgeInsets.only(bottom: 24),
//                   child: Column(
//                     children: [
//                       // ── BALANCE CARD ───────────────────────────────────
//                       _walletLoading
//                           ? _balanceCardSkeleton(c)
//                           : Container(
//                         margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//                         padding: const EdgeInsets.all(22),
//                         decoration: BoxDecoration(
//                           color: c.purpleLight,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment:
//                               MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text("Available balance",
//                                     style: TextStyle(
//                                         color: c.purple, fontSize: 13)),
//                                 GestureDetector(
//                                   onTap: () => setState(() =>
//                                   _balanceVisible = !_balanceVisible),
//                                   child: Icon(
//                                     _balanceVisible
//                                         ? Icons.visibility_outlined
//                                         : Icons.visibility_off_outlined,
//                                     size: 18,
//                                     color: c.purple,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               _balanceVisible
//                                   ? "₹$availableBalance"
//                                   : "₹$mask",
//                               style: TextStyle(
//                                   color: c.purpleDark,
//                                   fontSize: 38,
//                                   fontWeight: FontWeight.w600),
//                             ),
//                             Container(
//                               height: 1,
//                               margin:
//                               const EdgeInsets.symmetric(vertical: 16),
//                               color: c.purple.withOpacity(0.15),
//                             ),
//                             Row(
//                               mainAxisAlignment:
//                               MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Column(
//                                   crossAxisAlignment:
//                                   CrossAxisAlignment.start,
//                                   children: [
//                                     Text("Total",
//                                         style: TextStyle(
//                                             color:
//                                             c.purple.withOpacity(0.7),
//                                             fontSize: 12)),
//                                     const SizedBox(height: 2),
//                                     Text(
//                                       _balanceVisible
//                                           ? "₹$totalBalance"
//                                           : "₹$mask",
//                                       style: TextStyle(
//                                           color: c.purpleDark,
//                                           fontSize: 16,
//                                           fontWeight: FontWeight.w600),
//                                     ),
//                                   ],
//                                 ),
//                                 // FIX: new "Offline" column — this is the
//                                 // figure that actually moves when you make
//                                 // an offline payment (locking a reservation
//                                 // against the offline pool), instead of the
//                                 // change being invisible until sync.
//                                 if (offlineBalance > 0)
//                                   Column(
//                                     crossAxisAlignment:
//                                     CrossAxisAlignment.center,
//                                     children: [
//                                       Text("Offline",
//                                           style: TextStyle(
//                                               color: c.teal.withOpacity(
//                                                   0.85),
//                                               fontSize: 12)),
//                                       const SizedBox(height: 2),
//                                       Text(
//                                         _balanceVisible
//                                             ? "₹$offlineAvailable"
//                                             : "₹$mask",
//                                         style: TextStyle(
//                                             color: c.teal,
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600),
//                                       ),
//                                     ],
//                                   ),
//                                 if (lockedBalance > 0)
//                                   Column(
//                                     crossAxisAlignment:
//                                     CrossAxisAlignment.end,
//                                     children: [
//                                       Text("Locked",
//                                           style: TextStyle(
//                                               color: c.amber.withOpacity(
//                                                   0.85),
//                                               fontSize: 12)),
//                                       const SizedBox(height: 2),
//                                       Text(
//                                         _balanceVisible
//                                             ? "₹$lockedBalanceDisplay"
//                                             : "₹$mask",
//                                         style: TextStyle(
//                                             color: c.amber,
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600),
//                                       ),
//                                     ],
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       // ── QUICK ACTIONS ──────────────────────────────────
//                       Padding(
//                         padding:
//                         const EdgeInsets.symmetric(horizontal: 20),
//                         child: Align(
//                           alignment: Alignment.centerLeft,
//                           child: Text(
//                             "Quick actions",
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w600,
//                                 color: c.textSecondary),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 14),
//                       Padding(
//                         padding:
//                         const EdgeInsets.symmetric(horizontal: 16),
//                         child: Row(
//                           children: [
//                             Expanded(
//                                 child: _quickAction(
//                                     c,
//                                     "Send",
//                                     Icons.north_east_rounded,
//                                     c.purpleLight,
//                                     c.purple,
//                                         () => _navigate(const SendScreen()))),
//                             const SizedBox(width: 10),
//                             Expanded(
//                                 child: _quickAction(
//                                     c,
//                                     "Scan",
//                                     Icons.qr_code_scanner_rounded,
//                                     c.tealLight,
//                                     c.teal,
//                                         () =>
//                                         _navigate(const ScannerScreen()))),
//                             const SizedBox(width: 10),
//                             Expanded(
//                                 child: _quickAction(
//                                     c,
//                                     "Pending",
//                                     Icons.schedule_rounded,
//                                     c.amberLight,
//                                     c.amber,
//                                         () =>
//                                         _navigate(const PendingScreen()))),
//                             const SizedBox(width: 10),
//                             Expanded(
//                                 child: _quickAction(
//                                     c,
//                                     "History",
//                                     Icons.receipt_long_rounded,
//                                     c.blueLight,
//                                     c.blue,
//                                         () =>
//                                         _navigate(const HistoryScreen()))),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 28),
//                       PeopleRow(key: _peopleRowKey),
//
//                       // ── RECENT TRANSACTIONS ─────────────────────────────
//                       const SizedBox(height: 8),
//                       _recentTransactionsSection(c, _resolveUserId(auth)),
//
//                       const SizedBox(height: 24),
//                       const SizedBox(height: 20),
//                       Text(
//                         "© 2025 Built by moinworksonlocalhost",
//                         style: TextStyle(
//                             fontSize: 11, color: c.textSecondary),
//                       ),
//                       const SizedBox(height: 32),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────
//   // Balance card skeleton — same size/shape as the real card,
//   // filled with shimmering placeholder blocks.
//   // ─────────────────────────────────────────────────────────
//   Widget _balanceCardSkeleton(AppColors c) {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//       padding: const EdgeInsets.all(22),
//       decoration: BoxDecoration(
//         color: c.purpleLight,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: _ShimmerWrapper(
//         c: c,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 _skeletonBox(width: 110, height: 12),
//                 _skeletonBox(width: 18, height: 18, radius: 9),
//               ],
//             ),
//             const SizedBox(height: 10),
//             _skeletonBox(width: 160, height: 34),
//             Container(
//               height: 1,
//               margin: const EdgeInsets.symmetric(vertical: 16),
//               color: c.purple.withOpacity(0.1),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _skeletonBox(width: 40, height: 11),
//                     const SizedBox(height: 6),
//                     _skeletonBox(width: 70, height: 15),
//                   ],
//                 ),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     _skeletonBox(width: 40, height: 11),
//                     const SizedBox(height: 6),
//                     _skeletonBox(width: 70, height: 15),
//                   ],
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────
//   // Recent transactions card: header ("Recent Transactions" +
//   // "View All" + a small sync affordance so the old menu's sync
//   // action isn't lost), a list of up to 5 rows, a skeleton
//   // loading state, and an empty state.
//   // ─────────────────────────────────────────────────────────
//   Widget _recentTransactionsSection(AppColors c, String? currentUserId) {
//     final items = _recentTx;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.only(left: 4),
//                 child: Text(
//                   "Transactions",
//                   style: TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       color: c.textSecondary),
//                 ),
//               ),
//               Row(
//                 children: [
//                   GestureDetector(
//                     onTap: _handleSync,
//                     child: Icon(Icons.sync_rounded,
//                         size: 16, color: c.textSecondary.withOpacity(0.7)),
//                   ),
//                   const SizedBox(width: 14),
//                   GestureDetector(
//                     onTap: () => _navigate(const HistoryScreen()),
//                     child: Text(
//                       "View All",
//                       style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: c.purple),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: c.surface,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: c.border, width: 1),
//             ),
//             clipBehavior: Clip.antiAlias,
//             child: _txLoading
//                 ? _ShimmerWrapper(
//               c: c,
//               child: Column(
//                 children: [
//                   for (int i = 0; i < 4; i++) ...[
//                     _skeletonTxRow(),
//                     if (i != 3) _menuDivider(c),
//                   ],
//                 ],
//               ),
//             )
//                 : items.isEmpty
//                 ? Padding(
//               padding: const EdgeInsets.symmetric(
//                   vertical: 28, horizontal: 16),
//               child: Center(
//                 child: Column(
//                   children: [
//                     Icon(Icons.receipt_long_rounded,
//                         size: 26,
//                         color: c.textSecondary.withOpacity(0.5)),
//                     const SizedBox(height: 8),
//                     Text(
//                       "No transactions yet",
//                       style: TextStyle(
//                           fontSize: 13, color: c.textSecondary),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//                 : Column(
//               children: [
//                 for (int i = 0; i < items.length; i++) ...[
//                   _txRow(
//                     c,
//                     items[i],
//                     isReceived: items[i].receiverId == currentUserId,
//                   ),
//                   if (i != items.length - 1) _menuDivider(c),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _skeletonTxRow() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       child: Row(
//         children: [
//           _skeletonBox(width: 40, height: 40, radius: 12),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _skeletonBox(width: 110, height: 13),
//                 const SizedBox(height: 6),
//                 _skeletonBox(width: 130, height: 11),
//               ],
//             ),
//           ),
//           const SizedBox(width: 10),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               _skeletonBox(width: 56, height: 13),
//               const SizedBox(height: 6),
//               _skeletonBox(width: 40, height: 11),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _txRow(AppColors c, WalletTransaction tx, {required bool isReceived}) {
//     final iconBg = isReceived ? c.successBg : c.dangerBg;
//     final iconColor = isReceived ? c.successText : c.dangerText;
//     final amountColor = isReceived ? c.successText : c.dangerText;
//     final sign = isReceived ? "+" : "-";
//     final amountText = "$sign₹${tx.amount.toStringAsFixed(2)}";
//
//     // Same name-fallback pattern HistoryScreen uses.
//     final personName = isReceived
//         ? (tx.senderName.isNotEmpty && tx.senderName != "Unknown"
//         ? tx.senderName
//         : tx.senderId)
//         : (tx.receiverName.isNotEmpty && tx.receiverName != "Unknown"
//         ? tx.receiverName
//         : tx.receiverId);
//
//     // "Online/Offline • 26 Jul 2026, 07:49 pm" — mode + date/time,
//     // matching the reference design.
//     final modeAndTime =
//         "${tx.isOffline ? "Offline" : "Online"} • ${DateFormat("d MMM yyyy, h:mm a").format(tx.createdAt)}";
//
//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => TransactionDetailScreen(
//               tx: tx,
//               isReceived: isReceived,
//               personName: personName,
//               personPhone: "",
//             ),
//           ),
//         );
//       },
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//         child: Row(
//           children: [
//             Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 color: iconBg,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               alignment: Alignment.center,
//               child: Icon(
//                 isReceived
//                     ? Icons.south_west_rounded
//                     : Icons.north_east_rounded,
//                 color: iconColor,
//                 size: 18,
//               ),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(personName,
//                       overflow: TextOverflow.ellipsis,
//                       maxLines: 1,
//                       style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: c.textPrimary)),
//                   const SizedBox(height: 2),
//                   Text(
//                     modeAndTime,
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                     style:
//                     TextStyle(fontSize: 12, color: c.textSecondary),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 10),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text(amountText,
//                     style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: amountColor)),
//                 const SizedBox(height: 2),
//                 Text(tx.status,
//                     style:
//                     TextStyle(fontSize: 11, color: c.textSecondary)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _quickAction(AppColors c, String label, IconData icon, Color bg,
//       Color iconColor, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           Container(
//             width: 56,
//             height: 56,
//             decoration: BoxDecoration(
//               color: bg,
//               borderRadius: BorderRadius.circular(16),
//             ),
//             alignment: Alignment.center,
//             child: Icon(icon, color: iconColor, size: 22),
//           ),
//           const SizedBox(height: 8),
//           Text(label,
//               style: TextStyle(fontSize: 12, color: c.textSecondary)),
//         ],
//       ),
//     );
//   }
//
//   Widget _menuDivider(AppColors c) {
//     return Container(
//       height: 1,
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       color: c.border,
//     );
//   }
// }
//
//
// // ─────────────────────────────────────────────────────────
// // Generic skeleton block — a solid white rounded box. Colored
// // by whatever _ShimmerWrapper it's nested under.
// // ─────────────────────────────────────────────────────────
// Widget _skeletonBox({required double width, required double height, double radius = 4}) {
//   return Container(
//     width: width,
//     height: height,
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(radius),
//     ),
//   );
// }
//
// // ─────────────────────────────────────────────────────────
// // Wraps any skeleton content in a moving shimmer sweep. One
// // AnimationController per wrapped section (header, balance
// // card, transactions list) rather than per box, for cheap,
// // smooth animation.
// // ─────────────────────────────────────────────────────────
// class _ShimmerWrapper extends StatefulWidget {
//   final AppColors c;
//   final Widget child;
//   const _ShimmerWrapper({required this.c, required this.child});
//
//   @override
//   State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
// }
//
// class _ShimmerWrapperState extends State<_ShimmerWrapper>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat();
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final baseColor = widget.c.border.withOpacity(0.55);
//     final highlightColor = widget.c.border.withOpacity(0.15);
//
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, child) {
//         return ShaderMask(
//           blendMode: BlendMode.srcATop,
//           shaderCallback: (bounds) {
//             final t = _controller.value;
//             return LinearGradient(
//               colors: [baseColor, highlightColor, baseColor],
//               stops: const [0.0, 0.5, 1.0],
//               begin: Alignment(-1.0 - t * 2, 0),
//               end: Alignment(1.0 - t * 2, 0),
//             ).createShader(bounds);
//           },
//           child: child,
//         );
//       },
//       child: widget.child,
//     );
//   }
// }

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../offline/wallet_engine.dart';
import '../offline/sync_engine.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/wallet_transaction.dart';
import 'profile_screen.dart';
import 'send_screen.dart';
import 'scanner_screen.dart';
import 'pending_screen.dart';
import 'history_screen.dart';
import 'transaction_detail_screen.dart';
import 'login_screen.dart';
import 'dart:convert';
import '../widgets/people_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true;
  bool _balanceVisible = false;
  File? _profileImage;
  String _profileImageKey(String userId) => 'profile_image_path_$userId';

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final _peopleRowKey = GlobalKey<PeopleRowState>();

  // Recent transactions (same underlying data/cache as HistoryScreen).
  List<WalletTransaction> _recentTx = [];
  bool _txLoading = true;

  // Wallet/profile (header) initial-load state.
  bool _walletLoading = true;

  // Balance slider (Balance → Offline → Locked → loops).
  // Start in the middle of a huge range so you can swipe either way forever.
  final PageController _balanceController = PageController(initialPage: 3000);
  int _balancePage = 0;

  static const _avatarPalette = [
    Color(0xFFD6336C),
    Color(0xFF1565C0),
    Color(0xFF00695C),
    Color(0xFF6A1B9A),
    Color(0xFFD84315),
    Color(0xFF2E7D32),
    Color(0xFF4E342E),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();

      await auth.fetchWallet();

      if (!mounted) return;

      await Future.wait([
        _loadProfileImage(),
        _loadRecentTransactions(),
      ]);

      if (mounted) {
        setState(() => _walletLoading = false);
      }
    });
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
    Connectivity().checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
  }

  String? _resolveUserId(AuthProvider auth) {
    final user = auth.user;
    if (user == null || user.id.isEmpty) return null;
    return user.id;
  }

  // Loads the same data HistoryScreen shows (and shares its cache key),
  // then keeps the most recent 10 for the home screen list.
  Future<void> _loadRecentTransactions() async {
    final auth = context.read<AuthProvider>();
    final userId = _resolveUserId(auth);

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _recentTx = [];
          _txLoading = false;
        });
      }
      return;
    }

    final cacheKey = "cached_transactions_$userId";

    try {
      final response = await ApiService.instance.get("/wallet/transactions");
      final List<dynamic> data = response.data;

      final txs = data
          .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      await StorageService.setItem(cacheKey, jsonEncode(data));

      if (mounted) {
        setState(() {
          _recentTx = txs.take(10).toList();
          _txLoading = false;
        });
      }
    } catch (error) {
      debugPrint("❌ HOME RECENT TX ERROR (trying cache): $error");

      try {
        final cached = await StorageService.getItem(cacheKey);

        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          final txs = data
              .map((e) =>
              WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          if (mounted) {
            setState(() => _recentTx = txs.take(10).toList());
          }
        }
      } catch (e) {
        debugPrint("❌ HOME RECENT TX CACHE ERROR: $e");
      }

      if (mounted) {
        setState(() => _txLoading = false);
      }
    }
  }

  Future<bool> _hasBlockingState(AuthProvider auth) async {
    final lockedBalance = (auth.user?.wallet?.lockedBalance ?? 0).toDouble();
    if (lockedBalance > 0) return true;
    final userId = _resolveUserId(auth);

    if (userId == null || userId.isEmpty) return false;
    final pendingRaw =
    await StorageService.getItem("pending_transactions_$userId");
    if (pendingRaw != null) {
      try {
        final List<dynamic> pending = jsonDecode(pendingRaw);
        if (pending.isNotEmpty) return true;
      } catch (e) {
        debugPrint("PENDING TX PARSE ERROR (logout check): $e");
      }
    }
    return false;
  }

  Future<void> _loadProfileImage() async {
    final auth = context.read<AuthProvider>();
    final userId = _resolveUserId(auth);

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() => _profileImage = null);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profileImageKey(userId));

    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() => _profileImage = null);
      }
      return;
    }

    final file = File(path);

    if (await file.exists()) {
      if (!mounted) return;

      setState(() => _profileImage = file);
    } else {
      await prefs.remove(_profileImageKey(userId));

      if (mounted) {
        setState(() => _profileImage = null);
      }
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);

    // Show skeletons again while the refresh is in flight.
    if (mounted) {
      setState(() {
        _walletLoading = true;
        _txLoading = true;
      });
    }

    await auth.fetchWallet();

    await Future.wait([
      _loadProfileImage(),
      _loadRecentTransactions(),
    ]);

    _peopleRowKey.currentState?.refresh();

    if (mounted) {
      setState(() {
        _isOnline = online;
        _walletLoading = false;
      });
    }
  }

  Future<void> _handleSync() async {
    final auth = context.read<AuthProvider>();
    final walletEngine = WalletEngine(auth);
    final syncEngine = SyncEngine(auth, walletEngine);
    try {
      final result = await syncEngine.syncPendingTransactions();
      if (result["success"] == true) {
        await StorageService.removeItem("local_wallet");
        await Future.delayed(const Duration(milliseconds: 500));
        await auth.fetchWallet();
        if (mounted) _showAlert("Synced", "All transactions completed.");
      } else {
        if (mounted) {
          _showAlert("Nothing to sync",
              result["message"] ?? "No pending transactions.");
        }
      }
    } catch (error) {
      if (mounted) _showAlert("Error", "Sync failed");
    }
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthProvider>();
    final blocked = await _hasBlockingState(auth);
    if (blocked) {
      if (mounted) {
        _showAlert(
          "Cannot log out",
          "You have a locked balance or pending offline transactions that "
              "need to sync first. Please connect to the internet, sync, "
              "and try again.",
        );
      }
      return;
    }
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<void> _navigate(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (!mounted) return;

    // Refresh wallet first so the current account is ready.
    await context.read<AuthProvider>().fetchWallet();

    // Then load this account's profile image.
    await _loadProfileImage();

    if (mounted) {
      setState(() {});
      _peopleRowKey.currentState?.refresh();
    }
  }

  // Indian digit grouping with 2 decimals, e.g. 1,52,002.50
  String _money(double v) =>
      NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: 2)
          .format(v);

  // ─────────────────────────────────────────────────────────
  // BUILD — full-screen card
  //   header (profile · balance · people · locked | offline)
  //   transactions panel (fills the remaining space)
  //   action row (pinned to the bottom)
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);
    final isDark = theme.isDark;
    final user = auth.user;

    final balance = (user?.wallet?.balance ?? 0).toDouble();
    final offlineBalance = (user?.wallet?.offlineBalance ?? 0).toDouble();
    final lockedBalance = (user?.wallet?.lockedBalance ?? 0).toDouble();

    // Main balance is NOT reduced by lockedBalance (that money was already
    // moved into offlineBalance at recharge time).
    // The offline pool minus the currently locked reservation is what moves
    // when you spend offline.
    final offlineAvailable = offlineBalance - lockedBalance;

    final userName = user?.name.isNotEmpty == true ? user!.name : "User";

    final initials = userName
        .split(" ")
        .where((n) => n.isNotEmpty)
        .map((n) => n[0])
        .join("")
        .toUpperCase();
    final initialsShort =
    initials.length > 2 ? initials.substring(0, 2) : initials;

    const mask = "•••••";
    String show(double v) => _balanceVisible ? "₹ ${_money(v)}" : "₹ $mask";

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              color: isDark ? c.surface : null,
              gradient: isDark
                  ? null
                  : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7F8FB), Color(0xFFEAEEF4)],
              ),
              boxShadow: isDark
                  ? const [
                BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 14)),
              ]
                  : const [
                BoxShadow(
                    color: Color(0x1F8A96B8),
                    blurRadius: 30,
                    offset: Offset(0, 14)),
              ],
            ),
            child: Column(
              children: [
                _header(
                  c,
                  userName: userName,
                  initials: initialsShort,
                  balanceText: show(balance),
                  lockedText: show(lockedBalance),
                  offlineText: show(offlineAvailable),
                  onInfo: () => _showDetails(
                    c,
                    isDark: isDark,
                    mainBalance: show(balance),
                    offlineText:
                    offlineBalance > 0 ? show(offlineAvailable) : null,
                    lockedText: lockedBalance > 0 ? show(lockedBalance) : null,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _transactionsPanel(c, isDark, _resolveUserId(auth)),
                ),
                const SizedBox(height: 14),
                _actionRow(c, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BLUE HEADER
  // ─────────────────────────────────────────────────────────
  Widget _header(
      AppColors c, {
        required String userName,
        required String initials,
        required String balanceText,
        required String lockedText,
        required String offlineText,
        required VoidCallback onInfo,
      }) {
    const white70 = Color(0xB3FFFFFF);
    const white50 = Color(0x80FFFFFF);

    return SizedBox(
      height: 210,
      child: LayoutBuilder(
        builder: (context, cons) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Liquid grain background that follows the balance slider:
              //   Balance → green · Offline → red · Locked → blue
              Positioned.fill(
                child: _BalanceBackground(controller: _balanceController),
              ),

              // Profile (top-left)
              Positioned(
                left: 14,
                top: 14,
                child: _walletLoading
                    ? _ShimmerWrapper(
                  c: c,
                  base: const Color(0x59FFFFFF),
                  highlight: const Color(0x1FFFFFFF),
                  child: Row(
                    children: [
                      _skeletonBox(width: 34, height: 34, radius: 17),
                      const SizedBox(width: 8),
                      _skeletonBox(width: 70, height: 12),
                    ],
                  ),
                )
                    : Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigate(const ProfileScreen()),
                      child: Container(
                        width: 34,
                        height: 34,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: white50,
                        ),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.purple,
                          ),
                          child: _profileImage != null
                              ? Image.file(_profileImage!,
                              fit: BoxFit.cover,
                              width: 30,
                              height: 30)
                              : Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: math.max(80, cons.maxWidth - 140)),
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info button (top-right) — opens details sheet.
              // Small dot = online (green) / offline (red).
              Positioned(
                right: 14,
                top: 14,
                child: GestureDetector(
                  onTap: onInfo,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x33FFFFFF),
                          ),
                          child: const Text(
                            'i',
                            style: TextStyle(
                              color: white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFF6B6B),
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Sliding balance pages (loops forever):
              //   YOUR BALANCE → YOUR OFFLINE BALANCE → YOUR LOCKED BALANCE → …
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                height: 84,
                child: PageView.builder(
                  controller: _balanceController,
                  onPageChanged: (i) => setState(
                          () => _balancePage = i % _balanceTitles.length),
                  itemBuilder: (context, index) {
                    final page = index % _balanceTitles.length;
                    final amount = page == 0
                        ? balanceText
                        : page == 1
                        ? offlineText
                        : lockedText;
                    return _balancePageView(c, _balanceTitles[page], amount);
                  },
                ),
              ),

              // Page dots
              Positioned(
                top: 154,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _balanceTitles.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _balancePage ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _balancePage
                              ? Colors.white
                              : const Color(0x66FFFFFF),
                        ),
                      ),
                  ],
                ),
              ),

              // People avatars overlapping the bottom edge
              Positioned(
                left: 0,
                right: 0,
                bottom: -14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PeopleRow(key: _peopleRowKey, compact: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _balanceTitles = [
    'YOUR BALANCE',
    'YOUR OFFLINE BALANCE',
    'YOUR LOCKED BALANCE',
  ];

  // One page of the balance slider: label pill + amount.
  Widget _balancePageView(AppColors c, String title, String amount) {
    const white70 = Color(0xB3FFFFFF);

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _balanceVisible = !_balanceVisible),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: white70,
                    fontSize: 11.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _balanceVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 14,
                  color: white70,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _walletLoading
              ? _ShimmerWrapper(
            c: c,
            base: const Color(0x59FFFFFF),
            highlight: const Color(0x1FFFFFFF),
            child: _skeletonBox(width: 190, height: 38, radius: 10),
          )
              : GestureDetector(
            onTap: () =>
                setState(() => _balanceVisible = !_balanceVisible),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Color(0x40000000),
                      blurRadius: 14,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // TRANSACTIONS PANEL (fills the middle of the screen)
  // ─────────────────────────────────────────────────────────
  Widget _transactionsPanel(AppColors c, bool isDark, String? currentUserId) {
    final items = _recentTx;

    Widget listBody;
    if (_txLoading) {
      listBody = _ShimmerWrapper(
        c: c,
        child: Column(
          children: [
            for (int i = 0; i < 6; i++) _skeletonTxRow(),
          ],
        ),
      );
    } else if (items.isEmpty) {
      listBody = Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 30, color: c.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text(
                "No transactions yet",
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    } else {
      listBody = Column(
        children: [
          for (final tx in items) _txRow(c, tx, currentUserId),
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark ? c.bg : Colors.white,
        boxShadow: _neo(isDark),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last transactions',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _navigate(const HistoryScreen()),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: c.purple,
              onRefresh: _handleRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
                children: [
                  listBody,
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      "© 2025 Built by moinworksonlocalhost",
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonTxRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _skeletonBox(width: 46, height: 46, radius: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: 120, height: 14),
                const SizedBox(height: 7),
                _skeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          _skeletonBox(width: 60, height: 15),
        ],
      ),
    );
  }

  Widget _txRow(AppColors c, WalletTransaction tx, String? currentUserId) {
    final isReceived = tx.receiverId == currentUserId;

    // Same name-fallback pattern HistoryScreen uses.
    final personName = isReceived
        ? (tx.senderName.isNotEmpty && tx.senderName != "Unknown"
        ? tx.senderName
        : tx.senderId)
        : (tx.receiverName.isNotEmpty && tx.receiverName != "Unknown"
        ? tx.receiverName
        : tx.receiverId);

    final letter =
    personName.trim().isNotEmpty ? personName.trim()[0].toUpperCase() : '?';
    final avatarColor =
    _avatarPalette[personName.hashCode.abs() % _avatarPalette.length];

    final subtitle =
        "${tx.isOffline ? "Offline • " : ""}${DateFormat("MMM d • HH:mm").format(tx.createdAt)}";
    final amountText =
        "${isReceived ? "+" : "-"}₹${tx.amount.toStringAsFixed(2)}";

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(
              tx: tx,
              isReceived: isReceived,
              personName: personName,
              personPhone: "",
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor,
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: TextStyle(
                color: isReceived ? c.successText : c.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ACTION ROW (pinned to the bottom)
  //   ⬡ Profile · ⇅ Pending · Scan · Send   (History = "View all")
  // ─────────────────────────────────────────────────────────
  Widget _actionRow(AppColors c, bool isDark) {
    return Row(
      children: [
        _circleButton(
          c,
          isDark,
          onTap: () => _navigate(const ProfileScreen()),
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _HexSettingsPainter(c.textPrimary),
          ),
        ),
        const SizedBox(width: 10),
        _circleButton(
          c,
          isDark,
          onTap: () => _navigate(const PendingScreen()),
          child: Icon(Icons.swap_vert_rounded, size: 26, color: c.textPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: _pillButton(
            c,
            isDark,
            label: 'Scan',
            icon: Icons.qr_code_scanner_rounded,
            primary: false,
            onTap: () => _navigate(const ScannerScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: _pillButton(
            c,
            isDark,
            label: 'Send',
            icon: Icons.arrow_upward_rounded,
            primary: true,
            onTap: () => _navigate(const SendScreen()),
          ),
        ),
      ],
    );
  }

  List<BoxShadow> _neo(bool isDark) => isDark
      ? const [
    BoxShadow(
        color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8)),
  ]
      : const [
    BoxShadow(
        color: Color(0x1F7B88A8), blurRadius: 18, offset: Offset(0, 9)),
    BoxShadow(
        color: Color(0xFFFFFFFF), blurRadius: 12, offset: Offset(-4, -4)),
  ];

  Widget _circleButton(AppColors c, bool isDark,
      {required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? c.bg : null,
          gradient: isDark
              ? null
              : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF7F8FB)],
          ),
          boxShadow: _neo(isDark),
        ),
        child: child,
      ),
    );
  }

  Widget _pillButton(
      AppColors c,
      bool isDark, {
        required String label,
        required IconData icon,
        required bool primary,
        required VoidCallback onTap,
      }) {
    // Primary = black pill in light mode, white pill in dark mode.
    final blackStyle = primary && !isDark;
    final fg = primary
        ? (isDark ? const Color(0xFF111114) : Colors.white)
        : c.textPrimary;

    List<Color> colors;
    if (blackStyle) {
      colors = const [Color(0xFF3A3A3E), Color(0xFF0E0E10), Color(0xFF000000)];
    } else if (primary) {
      colors = const [Color(0xFFFFFFFF), Color(0xFFE3E5EA)];
    } else if (isDark) {
      colors = [c.bg, c.bg];
    } else {
      colors = const [Color(0xFFFFFFFF), Color(0xFFF7F8FB)];
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: blackStyle ? const [0.0, 0.55, 1.0] : null,
          ),
          boxShadow: blackStyle
              ? const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ]
              : _neo(isDark),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (blackStyle)
              const Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(22)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 19, color: fg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // DETAILS SHEET (info button): balances, sync, theme, logout
  // ─────────────────────────────────────────────────────────
  void _showDetails(
      AppColors c, {
        required bool isDark,
        required String mainBalance,
        required String? offlineText,
        required String? lockedText,
      }) {
    Widget row(String label, String value, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 14, color: c.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );

    Widget action(IconData icon, String label, VoidCallback onTap,
        {Color? color}) =>
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color ?? c.textSecondary),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color ?? c.textPrimary)),
              ],
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Wallet details',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isOnline ? c.successBg : c.dangerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isOnline ? c.successText : c.dangerText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              row('Main balance', mainBalance, c.textPrimary),
              if (offlineText != null)
                row('Offline balance', offlineText, c.teal),
              if (lockedText != null) row('Locked', lockedText, c.amber),
              Divider(color: c.border, height: 24),
              action(Icons.sync_rounded, 'Sync now', () {
                Navigator.pop(ctx);
                _handleSync();
              }),
              action(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                isDark ? 'Switch to light mode' : 'Switch to dark mode',
                    () {
                  Navigator.pop(ctx);
                  context.read<ThemeProvider>().toggle();
                },
              ),
              action(
                Icons.logout_rounded,
                'Log out',
                    () {
                  Navigator.pop(ctx);
                  _handleLogout();
                },
                color: c.dangerText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Hexagon "settings" icon from the design
// ─────────────────────────────────────────────────────────
class _HexSettingsPainter extends CustomPainter {
  const _HexSettingsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = size.center(Offset.zero);
    final r = size.width * 0.46;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 90);
      final p = Offset(ctr.dx + r * math.cos(a), ctr.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(ctr, size.width * 0.16, paint);
  }

  @override
  bool shouldRepaint(covariant _HexSettingsPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────
// Generic skeleton block — a solid white rounded box. Colored
// by whatever _ShimmerWrapper it's nested under.
// ─────────────────────────────────────────────────────────
Widget _skeletonBox(
    {required double width, required double height, double radius = 4}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// Wraps any skeleton content in a moving shimmer sweep.
// Optional [base]/[highlight] let it work on the blue header.
// ─────────────────────────────────────────────────────────
class _ShimmerWrapper extends StatefulWidget {
  final AppColors c;
  final Widget child;
  final Color? base;
  final Color? highlight;
  const _ShimmerWrapper({
    required this.c,
    required this.child,
    this.base,
    this.highlight,
  });

  @override
  State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<_ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.base ?? widget.c.border.withOpacity(0.55);
    final highlightColor =
        widget.highlight ?? widget.c.border.withOpacity(0.15);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 - t * 2, 0),
              end: Alignment(1.0 - t * 2, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


// ─────────────────────────────────────────────────────────
// LIQUID GRAIN BACKGROUND
// Cross-fades between three looks while you swipe the balance slider:
//   page 0 (Balance)  → green liquid grain
//   page 1 (Offline)  → red / orange liquid grain
//   page 2 (Locked)   → original blue gradient
// Everything is drawn in code (no image assets).
// ─────────────────────────────────────────────────────────
class _BalanceBackground extends StatelessWidget {
  const _BalanceBackground({required this.controller});

  final PageController controller;

  static const int _initialPage = 3000; // must match the PageController

  Widget _layer(int i) {
    switch (i) {
      case 0:
        return const RepaintBoundary(
          key: ValueKey('bg_green'),
          child: CustomPaint(
            painter: _LiquidPainter(_kGreen),
            size: Size.infinite,
          ),
        );
      case 1:
        return const RepaintBoundary(
          key: ValueKey('bg_red'),
          child: CustomPaint(
            painter: _LiquidPainter(_kRed),
            size: Size.infinite,
          ),
        );
      default:
        return const RepaintBoundary(
          key: ValueKey('bg_blue'),
          child: _BlueLayer(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          double page = _initialPage.toDouble();
          if (controller.hasClients &&
              controller.position.hasPixels &&
              controller.position.haveDimensions) {
            page = controller.page ?? page;
          }

          final base = page.floor();
          final t = page - base;
          final a = base % 3;
          final b = (base + 1) % 3;

          return Stack(
            fit: StackFit.expand,
            children: [
              _layer(a),
              if (t > 0.001) Opacity(opacity: t.clamp(0.0, 1.0), child: _layer(b)),
            ],
          );
        },
      ),
    );
  }
}

class _BlueLayer extends StatelessWidget {
  const _BlueLayer();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9DB4F8), Color(0xFF4A67E6)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -1.0),
            radius: 1.0,
            colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }
}

class _Blob {
  const _Blob(this.color, this.clear, this.cx, this.cy, this.r);
  final Color color; // centre colour (alpha baked in)
  final Color clear; // same colour, fully transparent
  final double cx, cy; // centre as a fraction of width / height
  final double r; // radius as a fraction of width
}

class _Ribbon {
  const _Ribbon(this.color, this.width, this.blur, this.p);
  final Color color;
  final double width; // stroke width as a fraction of height
  final double blur; // blur amount in logical px
  final List<Offset> p; // cubic bezier: start, ctrl1, ctrl2, end (fractions)
}

class _LiquidSpec {
  const _LiquidSpec({
    required this.base,
    required this.scrim,
    required this.blobs,
    required this.ribbons,
  });
  final Color base;
  final Color scrim;
  final List<_Blob> blobs;
  final List<_Ribbon> ribbons;
}

const _LiquidSpec _kGreen = _LiquidSpec(
  base: Color(0xFF3A982A),
  scrim: Color(0x1A000000),
  blobs: [
    _Blob(Color(0xE61B6A1A), Color(0x001B6A1A), 0.1, 0.1, 0.55),
    _Blob(Color(0xD90A3A0C), Color(0x000A3A0C), 0.8, 0.4, 0.22),
    _Blob(Color(0xA68FD14F), Color(0x008FD14F), 0.45, 0.05, 0.35),
  ],
  ribbons: [
    _Ribbon(Color(0xD90F4A12), 0.22, 10.0, [Offset(0.55, -0.1), Offset(0.95, 0.2), Offset(0.55, 0.5), Offset(0.78, 0.8)]),
    _Ribbon(Color(0xCCB7CC3E), 0.26, 14.0, [Offset(0.55, -0.05), Offset(1.0, -0.05), Offset(1.08, 0.4), Offset(0.88, 0.85)]),
    _Ribbon(Color(0xE6F5FFF3), 0.2, 14.0, [Offset(-0.1, 0.6), Offset(0.1, 0.95), Offset(0.55, 1.05), Offset(1.1, 0.8)]),
    _Ribbon(Color(0x8CE6FBE0), 0.09, 10.0, [Offset(0.0, 0.25), Offset(-0.02, 0.5), Offset(0.08, 0.8), Offset(0.2, 1.0)]),
  ],
);

const _LiquidSpec _kRed = _LiquidSpec(
  base: Color(0xFFD3301B),
  scrim: Color(0x1A000000),
  blobs: [
    _Blob(Color(0xE64A0F14), Color(0x004A0F14), 0.1, 0.15, 0.5),
    _Blob(Color(0xCCFF7A1A), Color(0x00FF7A1A), 0.3, 0.8, 0.4),
    _Blob(Color(0xCCB3122B), Color(0x00B3122B), 0.9, 0.8, 0.4),
  ],
  ribbons: [
    _Ribbon(Color(0xD93A0B12), 0.16, 8.0, [Offset(0.9, 0.05), Offset(0.2, -0.1), Offset(0.0, 0.5), Offset(0.35, 0.75)]),
    _Ribbon(Color(0xD9FF8A1F), 0.2, 10.0, [Offset(0.05, 0.95), Offset(0.0, 0.4), Offset(0.35, 0.1), Offset(0.6, 0.35)]),
    _Ribbon(Color(0xCCFFD54A), 0.14, 8.0, [Offset(0.15, 1.05), Offset(0.05, 0.6), Offset(0.3, 0.35), Offset(0.5, 0.5)]),
    _Ribbon(Color(0xD9F8E0E0), 0.16, 14.0, [Offset(1.08, 0.3), Offset(1.0, 0.6), Offset(0.8, 0.95), Offset(0.5, 1.08)]),
  ],
);

class _LiquidPainter extends CustomPainter {
  const _LiquidPainter(this.spec);

  final _LiquidSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 1) base colour
    canvas.drawRect(rect, Paint()..color = spec.base);

    // 2) big soft colour blobs
    for (final b in spec.blobs) {
      final center = Offset(b.cx * w, b.cy * h);
      final radius = b.r * w;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [b.color, b.clear])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // 3) blurred ribbons = the liquid swirl
    for (final r in spec.ribbons) {
      final p = r.p;
      final path = Path()
        ..moveTo(p[0].dx * w, p[0].dy * h)
        ..cubicTo(p[1].dx * w, p[1].dy * h, p[2].dx * w, p[2].dy * h,
            p[3].dx * w, p[3].dy * h);
      canvas.drawPath(
        path,
        Paint()
          ..color = r.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * h
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.blur / 2),
      );
    }

    // 4) slight darkening so white text stays readable
    canvas.drawRect(rect, Paint()..color = spec.scrim);

    // 5) film grain (seeded → identical every paint)
    final rnd = math.Random(7);
    final n = (w * h / 5).round();
    final light = <double>[];
    final dark = <double>[];
    for (int i = 0; i < n; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h;
      (rnd.nextBool() ? light : dark).addAll([x, y]);
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(light),
      Paint()
        ..color = const Color(0x26FFFFFF)
        ..strokeWidth = 1.0,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(dark),
      Paint()
        ..color = const Color(0x26000000)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter old) => old.spec != spec;
}