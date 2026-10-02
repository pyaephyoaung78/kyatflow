import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';

/// An offline guide for the workflows currently available in Kyat Flow.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How to use Kyat Flow')),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: CustomScrollView(
            key: const PageStorageKey('user_guide'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                sliver: SliverList.list(
                  children: const [
                    _GuideWelcome(),
                    SizedBox(height: 28),
                    SectionHeading('Start here'),
                    SurfaceGroup(
                      separatorInset: 68,
                      children: [
                        _GuideStep(
                          number: '1',
                          icon: CupertinoIcons.money_dollar_circle,
                          title: 'Add your income',
                          message:
                              'Tap the + button, choose Income, select Salary or another source, enter the amount, then save.',
                        ),
                        _GuideStep(
                          number: '2',
                          icon: CupertinoIcons.minus_circle,
                          title: 'Record an expense',
                          message:
                              'Tap +, choose Expense, select a category, enter the amount, and add an optional note.',
                        ),
                        _GuideStep(
                          number: '3',
                          icon: CupertinoIcons.house,
                          title: 'Check your overview',
                          message:
                              'Home shows your current balance plus this month’s income, expenses, recent entries, and budget progress.',
                        ),
                      ],
                    ),
                    SizedBox(height: 28),
                    SectionHeading('Stay on track'),
                    SurfaceGroup(
                      separatorInset: 68,
                      children: [
                        _GuideStep(
                          number: '4',
                          icon: CupertinoIcons.chart_pie,
                          title: 'Review your spending',
                          message:
                              'Use Analytics to compare This Week and This Month. Use History to filter All, Income, or Expense entries.',
                        ),
                        _GuideStep(
                          number: '5',
                          icon: CupertinoIcons.square_arrow_up,
                          title: 'Keep a backup',
                          message:
                              'Use the export button on Home to create a CSV backup and save a copy somewhere you trust.',
                        ),
                      ],
                    ),
                    SizedBox(height: 28),
                    SectionHeading('Helpful reminders'),
                    SurfaceGroup(
                      children: [
                        _GuideTip(
                          icon: CupertinoIcons.clock,
                          title: 'Record spending when it happens',
                          message:
                              'Small purchases are easy to forget. A quick entry keeps your monthly totals reliable.',
                        ),
                        _GuideTip(
                          icon: CupertinoIcons.text_alignleft,
                          title: 'Use notes for details',
                          message:
                              'Notes such as “Groceries” or “Weekend bus” make similar transactions easier to understand later.',
                        ),
                        _GuideTip(
                          icon: CupertinoIcons.lock_shield,
                          title: 'Your data stays local',
                          message:
                              'Kyat Flow stores your records on this device. Export backups regularly before changing phones.',
                        ),
                      ],
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
}

class _GuideWelcome extends StatelessWidget {
  const _GuideWelcome();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.accentSoft,
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.hand_thumbsup, color: AppTheme.accent, size: 26),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A simple daily habit', style: AppTheme.section),
              SizedBox(height: 6),
              Text(
                'Add income when you receive it and record each expense as it happens. Your monthly picture becomes clearer every day.',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.message,
  });
  final String number;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(message, style: AppTheme.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 5),
              Text(message, style: AppTheme.caption),
            ],
          ),
        ),
      ],
    ),
  );
}
