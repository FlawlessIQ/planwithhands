import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/features/shared_mode/shared_mode_controller.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';

class SharedModeLockOverlay extends ConsumerStatefulWidget {
  const SharedModeLockOverlay({super.key});

  @override
  ConsumerState<SharedModeLockOverlay> createState() => _SharedModeLockOverlayState();
}

class _SharedModeLockOverlayState extends ConsumerState<SharedModeLockOverlay> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref.watch(sharedModeControllerProvider);
    if (!shared.enabled || !shared.locked) return const SizedBox.shrink();

    final controller = ref.read(sharedModeControllerProvider.notifier);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              ModalBarrier(dismissible: false, color: Colors.black.withOpacity(0.55)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 520, maxHeight: constraints.maxHeight),
                    child: Container(
                      decoration: BoxDecoration(
                        color: HandsModalTokens.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: HandsModalTokens.border),
                        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 36, offset: Offset(0, 16))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: HandsColors.handsOrange.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: HandsColors.handsOrange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Shared mode',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: HandsColors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Select your name and unlock the device with your PIN.',
                                        style: HandsModalTokens.bodyStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const ContextHelpTrigger(
                                  title: 'Shared mode',
                                  subtitle:
                                      'Shared mode keeps team devices focused on work while requiring the right PIN for access changes.',
                                  topicIds: ['staff-shared-mode'],
                                  label: 'Help',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _search,
                              style: const TextStyle(
                                color: HandsColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HandsModalTokens.surfaceMuted,
                                hintText: 'Search team member',
                                hintStyle: const TextStyle(color: HandsModalTokens.textSubtle),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: HandsModalTokens.textSubtle,
                                  size: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: HandsModalTokens.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: HandsModalTokens.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: HandsColors.handsOrange, width: 1.3),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: StreamBuilder<List<Map<String, dynamic>>>(
                                stream: controller.eligibleUsersStream(),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final users = snap.data ?? const [];
                                  final q = _search.text.trim().toLowerCase();
                                  final filtered =
                                      q.isEmpty
                                          ? users
                                          : users
                                              .where((u) => u['displayName'].toString().toLowerCase().contains(q))
                                              .toList();

                                  if (filtered.isEmpty) {
                                    return Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: HandsModalTokens.surfaceElevated,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: HandsModalTokens.border),
                                        ),
                                        child: Text(
                                          users.isEmpty ? 'No staff found at this location.' : 'No matching users.',
                                          style: const TextStyle(
                                            color: HandsModalTokens.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final u = filtered[index];
                                      final hasPin = (u['hasPin'] == true);
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap:
                                            hasPin
                                                ? () async {
                                                  await _promptForPinAndActivate(
                                                    context,
                                                    controller,
                                                    targetUserId: u['id'].toString(),
                                                    name: u['displayName']?.toString() ?? 'User',
                                                  );
                                                }
                                                : () async {
                                                  await HandsDialog.show<void>(
                                                    context: context,
                                                    title: 'PIN required',
                                                    subtitle:
                                                        'This team member needs to set a Shared Mode PIN before they can unlock a shared device.',
                                                    maxWidth: 460,
                                                    child: Text(
                                                      'Ask them to sign in and use Menu → Set Shared Mode PIN first.',
                                                      style: HandsModalTokens.bodyStyle,
                                                    ),
                                                    actions: [
                                                      HandsPrimaryButton(
                                                        text: 'Got it',
                                                        onPressed: () => Navigator.of(context).pop(),
                                                      ),
                                                    ],
                                                  );
                                                },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: HandsModalTokens.surfaceElevated,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: HandsModalTokens.border),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color:
                                                      hasPin
                                                          ? HandsColors.handsOrange.withValues(alpha: 0.14)
                                                          : HandsModalTokens.surfaceMuted,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  hasPin ? Icons.person_outline_rounded : Icons.lock_outline_rounded,
                                                  color: hasPin ? HandsColors.handsOrange : HandsModalTokens.textMuted,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      u['displayName']?.toString() ?? 'User',
                                                      style: const TextStyle(
                                                        color: HandsColors.white,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      hasPin
                                                          ? (u['email']?.toString() ?? 'Tap to unlock')
                                                          : 'PIN not set yet',
                                                      style: const TextStyle(
                                                        color: HandsModalTokens.textMuted,
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 12.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                hasPin ? Icons.chevron_right_rounded : Icons.info_outline_rounded,
                                                color: HandsModalTokens.textMuted,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: HandsSecondaryButton(
                                    onPressed: () async {
                                      final ok = await _confirmHoldToSignOut(context);
                                      if (ok) {
                                        await controller.signOutDevice();
                                      }
                                    },
                                    icon: Icons.logout_rounded,
                                    text: 'Sign out device',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: HandsPrimaryButton(
                                    onPressed: () async {
                                      final exited = await _promptOwnerPinAndExitSharedMode(context);
                                      if (exited) {
                                        await controller.disableSharedMode();
                                      }
                                    },
                                    icon: Icons.lock_open_rounded,
                                    text: 'Leave Shared Mode',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _promptForPinAndActivate(
    BuildContext context,
    SharedModeController controller, {
    required String targetUserId,
    required String name,
  }) async {
    final pinController = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return HandsDialog(
              title: 'Unlock shared mode',
              subtitle: 'Enter the PIN for $name to continue on this device.',
              maxWidth: 440,
              actions: <Widget>[
                HandsSecondaryButton(text: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
                HandsPrimaryButton(
                  text: 'Continue',
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    try {
                      await controller.verifyAndActivateUser(userId: targetUserId, pin: pin);
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (e) {
                      setState(() => error = 'Invalid PIN');
                    }
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PIN', style: HandsModalTokens.labelStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: const TextStyle(color: HandsColors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter PIN',
                      errorText: error,
                      filled: true,
                      fillColor: HandsModalTokens.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsModalTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsModalTokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsColors.handsOrange, width: 1.3),
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

    pinController.dispose();
    return ok == true;
  }

  Future<bool> _promptOwnerPinAndExitSharedMode(BuildContext context) async {
    final controller = ref.read(sharedModeControllerProvider.notifier);
    final pinController = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return HandsDialog(
              title: 'Leave Shared Mode',
              subtitle: 'Enter the owner PIN for the person who enabled Shared Mode on this device.',
              maxWidth: 460,
              actions: <Widget>[
                HandsSecondaryButton(text: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
                HandsPrimaryButton(
                  text: 'Leave',
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final ok = await controller.verifyOwnerPinToExit(pin: pin);
                    if (!ok) {
                      setState(() => error = 'Invalid PIN');
                      return;
                    }
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Owner PIN', style: HandsModalTokens.labelStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: const TextStyle(color: HandsColors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter owner PIN',
                      errorText: error,
                      filled: true,
                      fillColor: HandsModalTokens.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsModalTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsModalTokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HandsColors.handsOrange, width: 1.3),
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

    pinController.dispose();
    return ok == true;
  }

  Future<bool> _confirmHoldToSignOut(BuildContext context) async {
    return (await HandsDialog.show<bool>(
          context: context,
          title: 'Sign out device',
          subtitle: 'This will sign out of the device and return to the login screen.',
          maxWidth: 420,
          child: const SizedBox.shrink(),
          actions: [
            HandsSecondaryButton(text: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
            HandsPrimaryButton(text: 'Sign out', onPressed: () => Navigator.of(context).pop(true)),
          ],
        )) ==
        true;
  }
}
