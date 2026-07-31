import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';

Future<void> showGalleryFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
        child: const GalleryFilterSheet(),
      ),
    ),
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
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _areDatesLoading = false;

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

  int get _selectedCount => _selectedValues.entries.fold<int>(
    0,
    (total, entry) =>
        total +
        (entry.key == 'date' && entry.value.isNotEmpty
            ? 1
            : entry.value.length),
  );

  int _selectedCountFor(String slug) {
    if (slug == 'my_smruti') {
      return _selectedValues.entries
          .where((entry) => entry.key.startsWith('my_smruti_'))
          .fold(0, (total, entry) => total + entry.value.length);
    }
    final count = _selectedValues[slug]?.length ?? 0;
    return slug == 'date' && count > 0 ? 1 : count;
  }

  List<String> get _selectedFilterLabels => _selectedOptions.values
      .expand((options) => options.values)
      .map((option) => option.label)
      .toList();

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

  void _updateDateSelection() {
    final dates = [_fromDate, _toDate].whereType<DateTime>().toList();
    if (dates.isEmpty) {
      _selectedValues.remove('date');
      _selectedOptions.remove('date');
      return;
    }
    final options = {
      for (final date in dates)
        _apiDate(date): GalleryFilterOption(
          value: _apiDate(date),
          label: _displayDate(date),
          count: 1,
        ),
    };
    _selectedValues['date'] = options.keys.toSet();
    _selectedOptions['date'] = options;
  }

  Future<void> _selectDate({required bool isFrom}) async {
    if (_areDatesLoading) return;
    setState(() => _areDatesLoading = true);
    Set<String> availableDates;
    try {
      availableDates = await _controller.loadAvailableFilterDates(
        selected: _selectedForApi,
      );
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _areDatesLoading = false);
    }
    if (!mounted || availableDates.isEmpty) return;
    final now = DateTime.now();
    final parsedAvailableDates =
        availableDates.map(DateTime.tryParse).whereType<DateTime>().toList()
          ..sort();
    if (parsedAvailableDates.isEmpty) return;
    final allowedDates = parsedAvailableDates.map(_apiDate).toSet();
    final fallbackDate = isFrom
        ? parsedAvailableDates.lastWhere(
            (date) => _toDate == null || !date.isAfter(_toDate!),
            orElse: () => parsedAvailableDates.first,
          )
        : parsedAvailableDates.firstWhere(
            (date) => _fromDate == null || !date.isBefore(_fromDate!),
            orElse: () => parsedAvailableDates.last,
          );
    final initialDate = isFrom
        ? (_fromDate ?? fallbackDate)
        : (_toDate ?? fallbackDate);
    final selected = await _showGlassDatePicker(
      context,
      initialDate: initialDate,
      minimumDate: isFrom ? parsedAvailableDates.first : _fromDate,
      maximumDate: isFrom
          ? _toDate ?? parsedAvailableDates.last
          : parsedAvailableDates.last.isAfter(now)
          ? now
          : parsedAvailableDates.last,
      selectableDayPredicate: (date) => allowedDates.contains(_apiDate(date)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = selected;
        if (_toDate != null && _toDate!.isBefore(selected)) _toDate = null;
      } else {
        _toDate = selected;
      }
      _updateDateSelection();
    });
    _controller.loadFilters(selected: _selectedForApi, force: true);
  }

  List<GalleryFilterGroup> _availableGroups(List<GalleryFilterGroup> groups) {
    final mySmrutiGroups = groups
        .where((group) => group.slug.startsWith('my_smruti_'))
        .toList();
    final regularGroups = groups
        .where((group) => !group.slug.startsWith('my_smruti_'))
        .toList();
    final availableGroups =
        <GalleryFilterGroup>[
              if (mySmrutiGroups.isNotEmpty ||
                  _controller.shouldShowMySmrutiFilterCategory)
                GalleryFilterGroup(
                  slug: 'my_smruti',
                  title: 'My Smruti',
                  options: mySmrutiGroups
                      .expand(
                        (group) => group.options.map(
                          (option) => GalleryFilterOption(
                            value: '${group.slug}:${option.value}',
                            label:
                                '${_mySmrutiSubgroupTitle(group)} ${option.label}',
                            count: option.count,
                          ),
                        ),
                      )
                      .toList(),
                ),
              const GalleryFilterGroup(
                slug: 'date',
                title: 'Date',
                options: [],
              ),
              ...regularGroups,
            ]
            .map(_withAvailableOptions)
            .where(
              (group) =>
                  group.slug == 'date' ||
                  group.slug == 'my_smruti' ||
                  group.options.isNotEmpty,
            )
            .toList();
    availableGroups.sort(
      (first, second) => _filterGroupOrder(
        first.slug,
      ).compareTo(_filterGroupOrder(second.slug)),
    );
    return availableGroups;
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
    final availableOptions =
        optionsByValue.values
            .where(
              (option) => option.count != 0 || selected.contains(option.value),
            )
            .toList()
          ..sort(_compareFilterOptions);
    return GalleryFilterGroup(
      slug: group.slug,
      title: group.title,
      options: availableOptions,
    );
  }

  List<GalleryFilterGroup> _searchMatchedGroups(
    List<GalleryFilterGroup> groups,
  ) {
    if (_query.isEmpty) return groups;
    return groups
        .where(
          (group) =>
              _filterGroupDisplayTitle(group).toLowerCase().contains(_query) ||
              group.options.any(
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
      _fromDate = null;
      _toDate = null;
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
        title: 'Filtered Smruti ($_selectedCount)',
        subtitle: '',
        selected: selected,
        filterLabels: _selectedFilterLabels,
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
          color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(245),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _controller.areFiltersRefreshing.value
                      ? LinearProgressIndicator(
                          key: const ValueKey('filter-refreshing'),
                          minHeight: 2,
                          color: primaryColor,
                          backgroundColor: primaryColor.withAlpha(18),
                        )
                      : const SizedBox(key: ValueKey('filter-idle'), height: 2),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final currentGroups = _controller
                      .filtersWithUserTagsForSelection(_selectedForApi);
                  if (_controller.areFiltersLoading.value &&
                      currentGroups.isEmpty) {
                    return const _FilterSheetLoading();
                  }
                  final availableGroups = _availableGroups(currentGroups);
                  if (availableGroups.isEmpty) {
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
                              selectedCount: _selectedCountFor(group.slug),
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
                          child: selected.slug.trim().toLowerCase() == 'date'
                              ? _DateFilterOptions(
                                  key: const ValueKey('date'),
                                  fromDate: _fromDate,
                                  toDate: _toDate,
                                  loading: _areDatesLoading,
                                  onSelectFrom: () => _selectDate(isFrom: true),
                                  onSelectTo: _fromDate == null
                                      ? null
                                      : () => _selectDate(isFrom: false),
                                  onClearFrom: _fromDate == null
                                      ? null
                                      : () {
                                          setState(() {
                                            _fromDate = null;
                                            _toDate = null;
                                            _updateDateSelection();
                                          });
                                          _controller.loadFilters(
                                            selected: _selectedForApi,
                                            force: true,
                                          );
                                        },
                                  onClearTo: _toDate == null
                                      ? null
                                      : () {
                                          setState(() {
                                            _toDate = null;
                                            _updateDateSelection();
                                          });
                                          _controller.loadFilters(
                                            selected: _selectedForApi,
                                            force: true,
                                          );
                                        },
                                )
                              : selected.slug == 'my_smruti'
                              ? _MySmrutiOptionsList(
                                  key: const ValueKey('my_smruti'),
                                  groups: currentGroups
                                      .where(
                                        (group) =>
                                            group.slug.startsWith('my_smruti_'),
                                      )
                                      .toList(),
                                  query: _query,
                                  loading: _controller
                                      .areMySmrutiFiltersLoading
                                      .value,
                                  selectedValues: _selectedValues,
                                  onChanged: _toggleOption,
                                )
                              : _FilterOptionsList(
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

int _compareFilterOptions(
  GalleryFilterOption first,
  GalleryFilterOption second,
) {
  final labelComparison = first.label.toLowerCase().compareTo(
    second.label.toLowerCase(),
  );
  if (labelComparison != 0) return labelComparison;

  return first.value.toLowerCase().compareTo(second.value.toLowerCase());
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
  switch (group.slug.trim().toLowerCase()) {
    case 'date':
      return 'Date';
    case 'subject':
      return 'Smruti';
    case 'person':
      return 'Darshan Of';
    case 'with':
      return 'Darshan With';
    case 'album':
      return 'Album';
    case 'sub_location':
      return 'Place';
    case 'location':
      return 'City';
    case 'country':
      return 'Country';
    case 'duration':
      return 'Year';
    case 'my_smruti_with':
      return 'Darshan With';
    case 'my_smruti_country':
      return 'Country';
    case 'my_smruti_location':
      return 'City';
    case 'my_smruti_place':
      return 'Place';
    case 'my_smruti_album':
      return 'Album';
    case 'my_smruti_darshan_of':
      return 'Darshan Of';
    case 'my_smruti_smruti_of':
      return 'Smruti';
    case 'my_smruti_tags':
      return 'Tags';
    case 'my_smruti':
      return 'My Smruti';
    case 'user_tag':
      return 'My Tags';
  }
  return group.title;
}

int _filterGroupOrder(String slug) {
  return switch (slug.trim().toLowerCase()) {
    'my_smruti' => -1,
    'my_smruti_with' => 0,
    'my_smruti_country' => 0,
    'my_smruti_location' => 1,
    'my_smruti_place' => 2,
    'my_smruti_album' => 3,
    'my_smruti_darshan_of' => 4,
    'my_smruti_smruti_of' => 5,
    'my_smruti_tags' => 6,
    'user_tag' => 7,
    'subject' => 10,
    'person' => 11,
    'with' => 12,
    'album' => 13,
    'sub_location' => 14,
    'location' => 15,
    'country' => 16,
    'duration' => 17,
    'date' => 18,
    _ => 19,
  };
}

String _mySmrutiSubgroupTitle(GalleryFilterGroup group) =>
    _filterGroupDisplayTitle(group);

class _MySmrutiOptionsList extends StatelessWidget {
  const _MySmrutiOptionsList({
    super.key,
    required this.groups,
    required this.query,
    required this.loading,
    required this.selectedValues,
    required this.onChanged,
  });

  final List<GalleryFilterGroup> groups;
  final String query;
  final bool loading;
  final Map<String, Set<String>> selectedValues;
  final void Function(GalleryFilterGroup group, GalleryFilterOption option)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = groups
        .map((group) {
          final options = query.isEmpty
              ? group.options
              : group.options
                    .where(
                      (option) =>
                          _mySmrutiSubgroupTitle(
                            group,
                          ).toLowerCase().contains(query) ||
                          option.label.toLowerCase().contains(query),
                    )
                    .toList();
          return GalleryFilterGroup(
            slug: group.slug,
            title: group.title,
            options: options,
          );
        })
        .where((group) => group.options.isNotEmpty)
        .toList();

    if (visibleGroups.isEmpty) {
      if (loading) {
        return const _FilterSheetLoading();
      }
      return const GalleryEmptyState(height: 240, message: 'No options found');
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 14),
      itemCount: visibleGroups.length,
      itemBuilder: (context, groupIndex) {
        final group = visibleGroups[groupIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, groupIndex == 0 ? 6 : 18, 4, 7),
              child: Text(
                _mySmrutiSubgroupTitle(group),
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final option in group.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _FilterOptionTile(
                  option: option,
                  selected:
                      selectedValues[group.slug]?.contains(option.value) ??
                      false,
                  onChanged: () => onChanged(group, option),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final GalleryFilterOption option;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final color = primaryColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(36) : color.withAlpha(16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color.withAlpha(130) : color.withAlpha(42),
        ),
      ),
      child: CheckboxListTile(
        value: selected,
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
            if (option.count >= 0) ...[
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (_) => onChanged(),
      ),
    );
  }
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
                if (option.count >= 0) ...[
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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

String _apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

class _DateFilterOptions extends StatelessWidget {
  const _DateFilterOptions({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.loading,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onClearFrom,
    required this.onClearTo,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final bool loading;
  final VoidCallback onSelectFrom;
  final VoidCallback? onSelectTo;
  final VoidCallback? onClearFrom;
  final VoidCallback? onClearTo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Text(
          'Select a date range',
          style: TextStyle(
            color: primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 2,
            color: primaryColor,
            backgroundColor: primaryColor.withAlpha(18),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'To find photos from one specific date, select only the From date.\n\n'
          'To find photos between two dates, select the start date in From '
          'and the end date in To. Both dates are included.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        _DatePickerField(
          label: 'From',
          value: fromDate == null ? null : _displayDate(fromDate!),
          onTap: onSelectFrom,
          onClear: onClearFrom,
        ),
        const SizedBox(height: 14),
        _DatePickerField(
          label: 'To',
          value: toDate == null ? null : _displayDate(toDate!),
          onTap: onSelectTo,
          onClear: onClearTo,
          enabled: onSelectTo != null,
        ),
        if (fromDate == null) ...[
          const SizedBox(height: 8),
          Text(
            'Select From date first',
            style: TextStyle(
              color: primaryColor.withAlpha(145),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: 'DD/MM/YYYY',
          enabled: enabled,
          filled: true,
          fillColor: enabled
              ? primaryColor.withAlpha(10)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          prefixIcon: const Icon(CupertinoIcons.calendar),
          suffixIcon: value == null
              ? const Icon(CupertinoIcons.chevron_down, size: 17)
              : IconButton(
                  tooltip: 'Clear $label date',
                  onPressed: onClear,
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor.withAlpha(45)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor.withAlpha(55)),
          ),
        ),
        child: Text(
          value ?? 'DD/MM/YYYY',
          style: TextStyle(
            color: value == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : primaryColor.withAlpha(230),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> _showGlassDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
  required DateTime maximumDate,
  required bool Function(DateTime) selectableDayPredicate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: minimumDate ?? DateTime(1900),
    lastDate: maximumDate,
    selectableDayPredicate: selectableDayPredicate,
    helpText: 'Select available date',
  );
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(250),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: selectedCount == 0 && !hasSearchQuery ? null : onClear,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Clear'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: selectedCount == 0 ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
