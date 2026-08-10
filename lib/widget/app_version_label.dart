import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class AppVersionLabel extends StatefulWidget {
  final TextStyle? style;

  const AppVersionLabel({super.key, this.style});

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<String> _label = _loadLabel();

  Future<String> _loadLabel() async {
    final package = await PackageInfo.fromPlatform();
    int? patchNumber;
    try {
      final updater = ShorebirdUpdater();
      if (updater.isAvailable) {
        patchNumber = (await updater.readCurrentPatch())?.number;
      }
    } catch (_) {
      // The store version is still useful if Shorebird is unavailable.
    }

    final build = package.buildNumber.trim();
    final version = build.isEmpty
        ? 'Version ${package.version}'
        : 'Version ${package.version} ($build)';
    return patchNumber == null
        ? '$version · Base'
        : '$version · Patch #$patchNumber';
  }

  @override
  Widget build(BuildContext context) {
    final fallbackStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return FutureBuilder<String>(
      future: _label,
      builder: (context, snapshot) => Text(
        snapshot.data ?? 'Version…',
        textAlign: TextAlign.center,
        style: widget.style ?? fallbackStyle,
      ),
    );
  }
}
