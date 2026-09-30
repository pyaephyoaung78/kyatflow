import 'package:flutter/material.dart';

IconData categoryIconFromKey(String? key) {
  return switch (key) {
    'restaurant' || 'food' => Icons.restaurant_rounded,
    'directions_bus' || 'transport' => Icons.directions_bus_rounded,
    'shopping_bag' || 'shopping' => Icons.shopping_bag_rounded,
    'receipt_long' || 'bills' => Icons.receipt_long_rounded,
    'medical_services' || 'health' => Icons.medical_services_rounded,
    'account_balance_wallet' ||
    'salary' => Icons.account_balance_wallet_rounded,
    'work' || 'freelance' => Icons.work_rounded,
    'card_giftcard' || 'gift' => Icons.card_giftcard_rounded,
    'savings' => Icons.savings_rounded,
    _ => Icons.category_rounded,
  };
}
