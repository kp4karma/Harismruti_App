import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/ui/view/gallery/gallery_timeline_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

Future<void> showGalleryFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const GalleryFilterSheet(),
  );
}

class GalleryFilterSheet extends StatefulWidget {
  const GalleryFilterSheet({super.key});

  @override
  State<GalleryFilterSheet> createState() => _GalleryFilterSheetState();
}

class _GalleryFilterSheetState extends State<GalleryFilterSheet> {
  final GalleryController _controller = Get.find<GalleryController>();
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.loadFilters();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.74;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          color: Colors.white.withAlpha(238),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter Smruti',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search filters',
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: primaryColor,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3EEE9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final groups = _controller.filters;
                  if (groups.isEmpty) return const _FilterSheetLoading();
                  final safeIndex = _selectedIndex >= groups.length
                      ? groups.length - 1
                      : _selectedIndex;
                  final selected = groups[safeIndex];
                  return Row(
                    children: [
                      SizedBox(
                        width: 126,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final isSelected = index == _selectedIndex;
                            return _FilterCategoryTile(
                              group: group,
                              selected: isSelected,
                              onTap: () => setState(() {
                                _selectedIndex = index;
                              }),
                            );
                          },
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: Colors.black.withAlpha(18),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          child: _FilterOptionsList(
                            key: ValueKey(selected.slug),
                            group: selected,
                            query: _query,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterCategoryTile extends StatelessWidget {
  final GalleryFilterGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _FilterCategoryTile({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.fromLTRB(10, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          group.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _FilterOptionsList extends StatelessWidget {
  final GalleryFilterGroup group;
  final String query;

  const _FilterOptionsList({
    super.key,
    required this.group,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final options = query.isEmpty
        ? group.options
        : group.options
              .where((option) => option.label.toLowerCase().contains(query))
              .toList();

    if (options.isEmpty && group.slug != 'duration') {
      return const GalleryEmptyState(height: 240, message: 'No options found');
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 18, 24),
      itemCount: options.length + (group.slug == 'duration' ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.black.withAlpha(16)),
      itemBuilder: (context, index) {
        if (group.slug == 'duration' && index == 0) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            leading: Icon(CupertinoIcons.calendar, color: primaryColor),
            title: const Text(
              'Browse Years',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            subtitle: const Text('Year, month and day timeline'),
            trailing: Icon(CupertinoIcons.chevron_right, color: primaryColor),
            onTap: () {
              Navigator.pop(context);
              Get.to(() => const GalleryTimelineScreen());
            },
          );
        }
        final option = options[group.slug == 'duration' ? index - 1 : index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          title: Text(
            option.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text('${option.count} Photos'),
          trailing: Icon(CupertinoIcons.chevron_right, color: primaryColor),
          onTap: () {
            Navigator.pop(context);
            if (group.slug == 'duration') {
              Get.to(
                () => GalleryTimelineScreen(year: int.tryParse(option.value)),
              );
            } else {
              Get.to(
                () => GalleryDetailScreen.fromFilter(
                  title: group.title,
                  slug: group.slug,
                  value: option.value,
                  count: option.count,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _FilterSheetLoading extends StatelessWidget {
  const _FilterSheetLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 126,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) =>
                const GalleryShimmerBox(height: 46, borderRadius: 16),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 18, 24),
            itemCount: 9,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) =>
                const GalleryShimmerBox(height: 58, borderRadius: 14),
          ),
        ),
      ],
    );
  }
}
