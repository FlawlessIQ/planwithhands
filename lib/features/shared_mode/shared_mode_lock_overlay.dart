import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/features/shared_mode/shared_mode_controller.dart';
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
                    child: Card(
                      color: HandsColors.cardPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lock, color: HandsColors.handsOrange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Shared Mode',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: HandsColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select your name and enter your PIN to continue.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _search,
                              style: const TextStyle(color: HandsColors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HandsColors.secondaryContainer,
                                hintText: 'Search name…',
                                hintStyle: const TextStyle(color: HandsColors.white30),
                                prefixIcon: const Icon(Icons.search, color: HandsColors.white30),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
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
                                      child: Text(
                                        users.isEmpty ? 'No staff found at this location.' : 'No matching users.',
                                        style: const TextStyle(color: HandsColors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1, color: HandsColors.white12),
                                    itemBuilder: (context, index) {
                                      final u = filtered[index];
                                      final hasPin = (u['hasPin'] == true);
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          u['displayName']?.toString() ?? 'User',
                                          style: const TextStyle(color: HandsColors.white),
                                        ),
                                        subtitle:
                                            hasPin
                                                ? ((u['email'] != null)
                                                    ? Text(
                                                      u['email'].toString(),
                                                      style: const TextStyle(color: HandsColors.white70),
                                                    )
                                                    : null)
                                                : const Text(
                                                  'PIN not set (must set PIN before using Shared Mode)',
                                                  style: TextStyle(color: HandsColors.white70),
                                                ),
                                        trailing: Icon(
                                          hasPin ? Icons.chevron_right : Icons.lock_outline,
                                          color: HandsColors.white70,
                                        ),
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
                                                  await showDialog<void>(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        title: const Text('PIN required'),
                                                        content: const Text(
                                                          'This staff member has not set a Shared Mode PIN yet.\n\nThey need to sign in and set a PIN (Menu → Set Shared Mode PIN) before they can use Shared Mode on shared devices.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(context).pop(),
                                                            child: const Text('OK'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await _confirmHoldToSignOut(context);
                                      if (ok) {
                                        await controller.signOutDevice();
                                      }
                                    },
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Sign out device'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      final exited = await _promptOwnerPinAndExitSharedMode(context);
                                      if (exited) {
                                        await controller.disableSharedMode();
                                      }
                                    },
                                    icon: const Icon(Icons.lock_open),
                                    label: const Text('Leave Shared Mode'),
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
            return AlertDialog(
              title: Text('Enter PIN for $name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'PIN', errorText: error),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    try {
                      await controller.verifyAndActivateUser(userId: targetUserId, pin: pin);
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (e) {
                      setState(() => error = 'Invalid PIN');
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
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
            return AlertDialog(
              title: const Text('Leave Shared Mode'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter the PIN of the person who enabled Shared Mode.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Owner PIN', errorText: error),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final ok = await controller.verifyOwnerPinToExit(pin: pin);
                    if (!ok) {
                      setState(() => error = 'Invalid PIN');
                      return;
                    }
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Leave'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    return ok == true;
  }

  Future<bool> _confirmHoldToSignOut(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Sign out device?'),
              content: const Text('This will sign out of the device and return to the login screen.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign out')),
              ],
            );
          },
        )) ==
        true;
  }
}
