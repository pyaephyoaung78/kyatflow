import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const FinancePage(
    title: 'Settings',
    children: [
      SurfaceGroup(
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
      SizedBox(height: 28),
      SectionHeading('Preferences'),
      SurfaceGroup(
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
      SizedBox(height: 28),
      SectionHeading('About'),
      SurfaceGroup(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.info_circle,
            title: 'About Kyat Flow',
            value: 'Version 1.0.0',
          ),
        ],
      ),
      Padding(
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
