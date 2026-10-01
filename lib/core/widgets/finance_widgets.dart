import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scrolling large titles and a single, consistent horizontal rhythm.
class FinancePage extends StatelessWidget {
  const FinancePage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.onRefresh,
    this.storageKey,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final String? storageKey;
  @override
  Widget build(BuildContext context) {
    Widget scroll = CustomScrollView(
      key: PageStorageKey(storageKey ?? title),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: AppTheme.title),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: AppTheme.caption),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppTheme.accent,
        child: scroll,
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: scroll,
          ),
        ),
      ),
    );
  }
}

class SurfaceGroup extends StatelessWidget {
  const SurfaceGroup({
    super.key,
    required this.children,
    this.separated = true,
    this.separatorInset = 16,
  });
  final List<Widget> children;
  final bool separated;
  final double separatorInset;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: ColoredBox(
      color: AppTheme.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (separated && i > 0)
              Divider(indent: separatorInset, endIndent: 16),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.detail});
  final String title;
  final String? detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppTheme.section),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 12),
          Text(detail!, style: AppTheme.caption),
        ],
      ],
    ),
  );
}

class FinanceSegments<T extends Object> extends StatelessWidget {
  const FinanceSegments({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
    required this.keyPrefix,
  });
  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: MediaQuery.disableAnimationsOf(context)
        ? CupertinoSegmentedControl<T>(
            groupValue: value,
            onValueChanged: onChanged,
            selectedColor: AppTheme.accent,
            unselectedColor: AppTheme.surface,
            borderColor: AppTheme.accent,
            padding: EdgeInsets.zero,
            children: {
              for (final entry in labels.entries)
                entry.key: Padding(
                  key: ValueKey(
                    '${keyPrefix}_${entry.key is Enum ? (entry.key as Enum).name : entry.key}',
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            },
          )
        : CupertinoSlidingSegmentedControl<T>(
            groupValue: value,
            backgroundColor: const Color(0xFFE9E9ED),
            thumbColor: AppTheme.surface,
            padding: const EdgeInsets.all(3),
            onValueChanged: (next) {
              if (next != null) onChanged(next);
            },
            children: {
              for (final entry in labels.entries)
                entry.key: Padding(
                  key: ValueKey(
                    '${keyPrefix}_${entry.key is Enum ? (entry.key as Enum).name : entry.key}',
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 4,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: value == entry.key
                          ? AppTheme.ink
                          : AppTheme.secondary,
                      fontWeight: value == entry.key
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
            },
          ),
  );
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    child: Column(
      children: [
        Icon(icon, size: 30, color: AppTheme.secondary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: AppTheme.caption),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class FinanceLoading extends StatelessWidget {
  const FinanceLoading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(56),
    child: Center(child: CupertinoActivityIndicator()),
  );
}
