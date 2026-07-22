import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
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
  final Map<String, Set<String>> _selectedValues = {};
  final Map<String, Map<String, GalleryFilterOption>> _selectedOptions = {};
  int _selectedIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.resetFiltersForSheet();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _selectedForApi {
    final selected = <String, List<String>>{};
    _selectedValues.forEach((slug, values) {
      if (values.isNotEmpty) selected[slug] = values.toList();
    });
    return selected;
  }

  int get _selectedCount => _selectedValues.values.fold<int>(
    0,
    (total, values) => total + values.length,
  );

  void _toggleOption(GalleryFilterGroup group, GalleryFilterOption option) {
    setState(() {
      final values = _selectedValues.putIfAbsent(group.slug, () => <String>{});
      if (!values.add(option.value)) {
        values.remove(option.value);
        _selectedOptions[group.slug]?.remove(option.value);
        if (_selectedOptions[group.slug]?.isEmpty ?? false) {
          _selectedOptions.remove(group.slug);
        }
      } else {
        _selectedOptions.putIfAbsent(
          group.slug,
          () => <String, GalleryFilterOption>{},
        )[option.value] = option;
      }
      if (values.isEmpty) _selectedValues.remove(group.slug);
    });
    _controller.loadFilters(selected: _selectedForApi, force: true);
  }

  List<GalleryFilterGroup> _availableGroups(List<GalleryFilterGroup> groups) {
    return groups
        .map(_withAvailableOptions)
        .where((group) => group.options.isNotEmpty)
        .toList();
  }

  GalleryFilterGroup _withAvailableOptions(GalleryFilterGroup group) {
    final selected = _selectedValues[group.slug] ?? const <String>{};
    final optionsByValue = <String, GalleryFilterOption>{
      for (final option in group.options) option.value: option,
    };
    for (final value in selected) {
      final selectedOption = _selectedOptions[group.slug]?[value];
      if (selectedOption != null) {
        optionsByValue.putIfAbsent(value, () => selectedOption);
      }
    }
    return GalleryFilterGroup(
      slug: group.slug,
      title: group.title,
      options: optionsByValue.values
          .where(
            (option) => option.count > 0 || selected.contains(option.value),
          )
          .toList(),
    );
  }

  List<GalleryFilterGroup> _searchMatchedGroups(
    List<GalleryFilterGroup> groups,
  ) {
    if (_query.isEmpty) return groups;
    return groups
        .where(
          (group) => group.options.any(
            (option) => option.label.toLowerCase().contains(_query),
          ),
        )
        .toList();
  }

  void _clearFilters() {
    if (_selectedValues.isEmpty && _query.isEmpty) return;
    setState(() {
      _selectedValues.clear();
      _selectedOptions.clear();
      _selectedIndex = 0;
    });
    _searchController.clear();
    _controller.loadFilters(force: true);
  }

  void _applyFilters() {
    final selected = _selectedForApi;
    if (selected.isEmpty) return;
    Navigator.pop(context);
    Get.to(
      () => GalleryDetailScreen.fromFilters(
        title: 'Filtered Smruti',
        subtitle: '$_selectedCount selected filters',
        selected: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          color: Colors.white.withAlpha(238),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
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
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
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
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final availableGroups = _availableGroups(
                    _controller.filtersWithUserTags,
                  );
                  if (availableGroups.isEmpty) {
                    if (_controller.areFiltersLoading.value) {
                      return const _FilterSheetLoading();
                    }
                    if (_controller.filtersError.value.isNotEmpty) {
                      return _FilterSheetError(
                        message: _controller.filtersError.value,
                        onRetry: () => _controller.loadFilters(
                          selected: _selectedForApi,
                          force: true,
                        ),
                      );
                    }
                    return Center(
                      child: Text(
                        'No filters available',
                        style: TextStyle(
                          color: primaryColor.withAlpha(170),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  final groups = _searchMatchedGroups(availableGroups);
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(
                        'No options found',
                        style: TextStyle(
                          color: primaryColor.withAlpha(170),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  final safeIndex = _selectedIndex >= groups.length
                      ? groups.length - 1
                      : _selectedIndex;
                  final selected = groups[safeIndex];
                  return Row(
                    children: [
                      SizedBox(
                        width: 116,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final isSelected = index == safeIndex;
                            return _FilterCategoryTile(
                              group: group,
                              selected: isSelected,
                              selectedCount:
                                  _selectedValues[group.slug]?.length ?? 0,
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
                            selectedValues:
                                _selectedValues[selected.slug] ??
                                const <String>{},
                            onChanged: (option) =>
                                _toggleOption(selected, option),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              _FilterActionsBar(
                selectedCount: _selectedCount,
                hasSearchQuery: _query.isNotEmpty,
                onClear: _clearFilters,
                onApply: _applyFilters,
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
  final int selectedCount;
  final VoidCallback onTap;

  const _FilterCategoryTile({
    required this.group,
    required this.selected,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.fromLTRB(8, 3, 6, 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? primaryColor : primaryColor.withAlpha(10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _filterGroupDisplayTitle(group),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : primaryColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (selectedCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : primaryColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$selectedCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? primaryColor : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _filterGroupDisplayTitle(GalleryFilterGroup group) {
  final title = group.title.trim();
  if (title.toLowerCase() == 'location') return 'Place';
  if (title.toLowerCase() == 'locations') return 'Places';
  return group.title;
}

class _FilterOptionsList extends StatelessWidget {
  final GalleryFilterGroup group;
  final String query;
  final Set<String> selectedValues;
  final ValueChanged<GalleryFilterOption> onChanged;

  const _FilterOptionsList({
    super.key,
    required this.group,
    required this.query,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = query.isEmpty
        ? group.options
        : group.options
              .where((option) => option.label.toLowerCase().contains(query))
              .toList();

    if (options.isEmpty) {
      return const GalleryEmptyState(height: 240, message: 'No options found');
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 14),
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selectedValues.contains(option.value);
        final color = primaryColor;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(36) : color.withAlpha(16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color.withAlpha(130) : color.withAlpha(42),
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            activeColor: color,
            dense: true,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -4),
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withAlpha(235),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.photo_on_rectangle,
                  size: 12,
                  color: color.withAlpha(165),
                ),
                const SizedBox(width: 3),
                Text(
                  '${option.count}',
                  style: TextStyle(
                    color: Colors.black.withAlpha(120),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => onChanged(option),
          ),
        );
      },
    );
  }
}

class _FilterActionsBar extends StatelessWidget {
  final int selectedCount;
  final bool hasSearchQuery;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const _FilterActionsBar({
    required this.selectedCount,
    required this.hasSearchQuery,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(245),
          border: Border(top: BorderSide(color: Colors.black.withAlpha(14))),
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: selectedCount == 0 && !hasSearchQuery ? null : onClear,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: selectedCount == 0 ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black.withAlpha(22),
                  disabledForegroundColor: Colors.black.withAlpha(95),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  selectedCount == 0
                      ? 'Select filters'
                      : 'Apply $selectedCount filters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
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

class _FilterSheetError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FilterSheetError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: primaryColor.withAlpha(170),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor.withAlpha(170),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
