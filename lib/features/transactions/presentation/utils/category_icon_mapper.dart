import 'package:flutter/cupertino.dart';

IconData categoryIconFromKey(String? key) {
  return switch (key) {
    'restaurant' || 'food' => CupertinoIcons.cart,
    'directions_bus' || 'transport' => CupertinoIcons.car_detailed,
    'shopping_bag' || 'shopping' => CupertinoIcons.bag,
    'receipt_long' || 'bills' => CupertinoIcons.doc_text,
    'medical_services' || 'health' => CupertinoIcons.heart,
    'account_balance_wallet' || 'salary' => CupertinoIcons.creditcard,
    'work' || 'freelance' => CupertinoIcons.briefcase,
    'card_giftcard' || 'gift' => CupertinoIcons.gift,
    'savings' => CupertinoIcons.money_dollar_circle,
    _ => CupertinoIcons.square_grid_2x2,
  };
}
