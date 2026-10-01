import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/finance_entry_route.dart';
import '../models/transaction_category_option.dart';
import '../providers/transaction_providers.dart';
import '../utils/category_icon_mapper.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'ledger_screen.dart';
import 'settings_screen.dart';
import 'transaction_entry_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});
  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _transition,
    curve: Curves.easeOutCubic,
  );
  static const _screens = [
    DashboardScreen(),
    AnalyticsScreen(),
    LedgerScreen(),
    SettingsScreen(),
  ];
  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _transition.value = 1;
    } else {
      _transition.forward(from: 0.65);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FadeTransition(
      opacity: _fade,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _screens.length; i++)
            TickerMode(enabled: i == _selectedIndex, child: _screens[i]),
        ],
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.line, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _tab(
                0,
                'Home',
                CupertinoIcons.house,
                CupertinoIcons.house_fill,
                'home_tab',
              ),
              _tab(
                1,
                'Analytics',
                CupertinoIcons.chart_pie,
                CupertinoIcons.chart_pie_fill,
                'analytics_tab',
              ),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Add transaction',
                    child: CupertinoButton(
                      key: const ValueKey('add_transaction'),
                      padding: EdgeInsets.zero,
                      onPressed: _openTransactionEntry,
                      child: Semantics(
                        label: 'Add transaction',
                        button: true,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _tab(
                2,
                'History',
                CupertinoIcons.list_bullet,
                CupertinoIcons.list_bullet,
                'ledger_tab',
              ),
              _tab(
                3,
                'Settings',
                CupertinoIcons.gear,
                CupertinoIcons.gear_solid,
                'settings_tab',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tab(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
    String key,
  ) {
    final selected = index == _selectedIndex;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: CupertinoButton(
          key: ValueKey(key),
          padding: const EdgeInsets.symmetric(vertical: 8),
          onPressed: () => _select(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 23,
                color: selected ? AppTheme.accent : AppTheme.secondary,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? AppTheme.accent : AppTheme.secondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTransactionEntry() async {
    final categories = ref.read(dashboardStateProvider).categories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories are still loading. Try again.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      FinanceEntryRoute(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => RiverpodTransactionEntryScreen(
          categories: categories
              .map(
                (category) => TransactionCategoryOption(
                  id: category.id,
                  name: category.name,
                  icon: categoryIconFromKey(category.icon),
                  color: Color(category.color),
                  type: category.type,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
