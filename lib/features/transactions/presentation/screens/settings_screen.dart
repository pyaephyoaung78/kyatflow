import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import 'user_guide_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => FinancePage(
    title: 'Settings',
    children: [
      const SurfaceGroup(
        children: [
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.lock_shield,
                  size: 30,
                  color: AppTheme.accent,
                ),
                SizedBox(height: 16),
                Text('Local-first by design', style: AppTheme.section),
                SizedBox(height: 8),
                Text(
                  'Your money is personal. Your records stay on this device.',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      const SectionHeading('Help'),
      SurfaceGroup(
        children: [
          _SettingsLinkRow(
            key: const ValueKey('open_user_guide'),
            icon: CupertinoIcons.question_circle,
            title: 'How to use Kyat Flow',
            value: 'A quick guide to tracking your money',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const UserGuideScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      const SectionHeading('Preferences'),
      const SurfaceGroup(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.money_dollar_circle,
            title: 'Currency',
            value: 'Myanmar Kyat (MMK)',
          ),
          _SettingsRow(
            icon: CupertinoIcons.calendar,
            title: 'Week starts on',
            value: 'Monday',
          ),
        ],
      ),
      const SizedBox(height: 28),
      const SectionHeading('About'),
      const SurfaceGroup(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.info_circle,
            title: 'About Kyat Flow',
            value: 'Version 1.0.0',
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text(
          'Keep a copy of your records using the export button on Home.',
          style: AppTheme.caption,
        ),
      ),
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.secondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: AppTheme.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: AppTheme.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: AppTheme.secondary,
          ),
        ],
      ),
    ),
  );
}
