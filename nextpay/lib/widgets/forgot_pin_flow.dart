import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_lock_service.dart';

/// Shown when someone has forgotten their ZeroBars PIN.
///
/// The PIN only ever lives on this device (it's a salted hash in secure
/// storage — there's nothing for a server to check it against), so the only
/// safe way to reset it is to clear the stored PIN and require the person to
/// prove who they are again the same way they did the first time: by
/// logging back in with an OTP. Skipping that step would mean anyone who
/// picks up the phone could just tap "forgot PIN" and set a new one,
/// defeating the point of having a PIN at all.
///
/// Once they're signed back in, [OnboardingGate] sees there's no PIN saved
/// and naturally prompts them to set a new one — no extra plumbing needed.
Future<void> showForgotPinFlow(
  BuildContext context, {
  /// Pass true when this is called from a screen that was pushed on top of
  /// the root route (e.g. the mid-payment PIN sheet), so we pop back down
  /// to the root before signing out. LockScreen doesn't need this — it's
  /// already the thing being displayed at the root.
  bool popToRoot = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset your PIN?'),
      content: const Text(
        "For your security, you'll be signed out and asked to verify your "
        "mobile number with an OTP. Once verified, you can set a new PIN.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reset PIN'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await AppLockService.instance.clearLock();
  if (!context.mounted) return;

  if (popToRoot) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  await context.read<AuthProvider>().logout();
}
