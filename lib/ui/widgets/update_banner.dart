import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/update_service.dart' show UpdatePhase;
import '../../state/app_state.dart';

/// Sliding banner shown when a newer GitHub release is available.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final show = state.pendingUpdate != null && !state.updateDismissed;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show
          ? Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  DragonColors.ember.withValues(alpha: 0.16),
                  DragonColors.emberDeep.withValues(alpha: 0.10),
                ]),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: DragonColors.ember.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.system_update_alt_rounded,
                      color: DragonColors.gold, size: 20),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'نسخه ${state.pendingUpdate!.version} در دسترس است — به‌روزرسانی کن!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showUpdateSheet(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: DragonColors.ember,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('به‌روزرسانی',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.read<AppState>().dismissUpdate(),
                    icon: Icon(Icons.close_rounded,
                        size: 17,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ).animate().slideY(begin: -0.4, end: 0, duration: 350.ms, curve: Curves.easeOutCubic).fadeIn()
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Bottom sheet driving download → install with live progress.
Future<void> showUpdateSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (sheetContext) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
      decoration: BoxDecoration(
        color: Theme.of(sheetContext).brightness == Brightness.dark
            ? DragonColors.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DragonColors.stroke),
      ),
      child: SafeArea(
        top: false,
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final info = state.pendingUpdate;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: DragonColors.stroke,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.rocket_launch_rounded,
                        color: DragonColors.gold, size: 22),
                    const SizedBox(width: 10),
                    Text('به‌روزرسانی Dragon Agent',
                        style: Theme.of(sheetContext).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  info != null
                      ? 'نسخه جدید: ${info.version}  ·  نسخه فعلی: ${state.appVersion}'
                      : 'در حال دریافت اطلاعات…',
                  style: TextStyle(
                      fontSize: 12.5, color: DragonColors.textDim),
                ),
                const SizedBox(height: 18),
                if (state.updatePhase == UpdatePhase.downloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: state.downloadProgress <= 0
                          ? null
                          : state.downloadProgress,
                      minHeight: 8,
                      backgroundColor: DragonColors.card,
                      valueColor:
                          const AlwaysStoppedAnimation(DragonColors.ember),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.downloadProgress > 0
                        ? 'در حال دانلود… ${(state.downloadProgress * 100).toStringAsFixed(0)}٪'
                        : 'در حال دانلود…',
                    style: TextStyle(fontSize: 12, color: DragonColors.textDim),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.updatePhase == UpdatePhase.error) ...[
                  Text(
                    'خطا در دانلود: ${state.updateError ?? 'نامشخص'}',
                    style: TextStyle(
                        fontSize: 12.5, color: DragonColors.emberDeep, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    if (state.updatePhase == UpdatePhase.downloaded) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: DragonColors.ember,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () =>
                              context.read<AppState>().installUpdate(),
                          icon: const Icon(Icons.install_mobile_rounded),
                          label: const Text('نصب نسخه جدید',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: DragonColors.ember,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: state.updatePhase == UpdatePhase.downloading
                              ? null
                              : () =>
                                  context.read<AppState>().downloadUpdate(),
                          icon: state.updatePhase == UpdatePhase.downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white))
                              : const Icon(Icons.download_rounded),
                          label: Text(
                            state.updatePhase == UpdatePhase.downloaded
                                ? 'دانلود دوباره'
                                : 'دانلود و نصب',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'نصب روی نسخه قبلی انجام می‌شود — نیازی به پاک کردن اپ نیست.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: DragonColors.textDim),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
