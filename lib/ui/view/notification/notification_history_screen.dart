import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/healper_service/notification_service.dart';
import 'package:harismruti/services/notification_history_service.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/background/custom_background.dart';
import 'package:harismruti/widget/appbar/frosted_appbar.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.brightness == Brightness.dark
        ? const Color(0xFFFFB4A5)
        : primaryColor;
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: FrostedAppBar(
          title: const Text('Notifications'),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: NotificationHistoryService.revision,
              builder: (_, __, ___) {
                if (NotificationHistoryService.unreadCount == 0) {
                  return const SizedBox.shrink();
                }
                return TextButton(
                  onPressed: NotificationHistoryService.markAllRead,
                  style: TextButton.styleFrom(foregroundColor: accent),
                  child: const Text('Mark all read'),
                );
              },
            ),
          ],
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: NotificationHistoryService.revision,
          builder: (context, _, __) {
            final entries = NotificationHistoryService.entries;
            if (entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.bell,
                      size: 52,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _NotificationCard(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFFFB4A5) : primaryColor;
    final imageUrl = entry['image_url']?.toString() ?? '';
    final isUnread = entry['is_read'] != true;
    return Material(
      color: isUnread
          ? Color.alphaBlend(
              accent.withAlpha(isDark ? 30 : 18),
              scheme.surfaceContainerHigh,
            )
          : scheme.surfaceContainer.withAlpha(isDark ? 238 : 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isUnread
              ? accent.withAlpha(isDark ? 65 : 40)
              : scheme.outlineVariant.withAlpha(120),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          NotificationHistoryService.markRead(entry['id'].toString());
          NotificationService.openSavedNotification(entry);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackIcon(context),
                  ),
                )
              else
                _fallbackIcon(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry['title']?.toString() ?? 'Notification',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: accent.withAlpha(80),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry['body']?.toString() ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _displayTime(entry['received_at']?.toString()),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.brightness == Brightness.dark
        ? const Color(0xFFFFB4A5)
        : primaryColor;
    return Container(
      width: 82,
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(CupertinoIcons.bell_fill, color: accent),
    );
  }

  String _displayTime(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
