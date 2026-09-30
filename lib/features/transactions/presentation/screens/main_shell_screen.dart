import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DashboardScreen(),
          AnalyticsScreen(),
          SizedBox.shrink(),
          LedgerScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        button: true,
        label: 'Add transaction',
        child: FloatingActionButton(
          key: const ValueKey('add_transaction'),
          heroTag: 'main_add_transaction',
          tooltip: 'Add transaction',
          onPressed: _openTransactionEntry,
          backgroundColor: const Color(0xFF183D32),
          foregroundColor: Colors.white,
          elevation: 5,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: _MainBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        onAdd: _openTransactionEntry,
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
      MaterialPageRoute(
        fullscreenDialog: true,
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

class _MainBottomNavigation extends StatelessWidget {
  const _MainBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 76,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x22000000),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _NavigationDestination(
            key: const ValueKey('home_tab'),
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _NavigationDestination(
            key: const ValueKey('analytics_tab'),
            label: 'Analytics',
            icon: Icons.pie_chart_outline_rounded,
            selectedIcon: Icons.pie_chart_rounded,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _AddDestination(onTap: onAdd),
          _NavigationDestination(
            key: const ValueKey('ledger_tab'),
            label: 'History',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            selected: selectedIndex == 3,
            onTap: () => onSelected(3),
          ),
          _NavigationDestination(
            key: const ValueKey('settings_tab'),
            label: 'Settings',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            selected: selectedIndex == 4,
            onTap: () => onSelected(4),
          ),
        ],
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2E6755) : Colors.black45;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFDCEAE4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDestination extends StatelessWidget {
  const _AddDestination({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Add transaction',
        child: InkResponse(
          key: const ValueKey('add_tab'),
          onTap: onTap,
          radius: 30,
          child: const Padding(
            padding: EdgeInsets.only(top: 39),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFF183D32),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
