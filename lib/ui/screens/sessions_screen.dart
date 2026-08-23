import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/flame_logo.dart';

/// Sessions browser — episodic memory made visible.
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final metas = state.sessions.metas;

    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: metas.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlameLogo(size: 54),
                  const SizedBox(height: 14),
                  Text('No sessions yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('Every conversation is saved here — resumable anytime.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: metas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = metas[i];
                return Dismissible(
                  key: ValueKey(m.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => state.deleteSession(m.id),
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: DragonColors.emberDeep.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child:
                        const Icon(Icons.delete_outline_rounded, color: DragonColors.emberDeep),
                  ),
                  child: Material(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DragonColors.card
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await state.openSession(m.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DragonColors.ember.withValues(alpha: 0.22),
                                    DragonColors.emberDeep.withValues(alpha: 0.10),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  const Icon(Icons.forum_outlined, size: 17, color: DragonColors.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _fmt(m.updatedAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _fmt(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.year}/${t.month}/${t.day}';
  }
}
