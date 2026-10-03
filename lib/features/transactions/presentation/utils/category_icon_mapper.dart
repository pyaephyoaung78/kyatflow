import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

IconData categoryIconFromKey(String? key) {
  return switch (key) {
    'restaurant' || 'food' => CupertinoIcons.cart,
    'directions_bus' || 'transport' => CupertinoIcons.car_detailed,
    'shopping_bag' || 'shopping' => CupertinoIcons.bag,
    'receipt_long' || 'bills' => CupertinoIcons.doc_text,
    'medical_services' || 'health' => CupertinoIcons.heart,
    'cigarettes' || 'smoking' => Icons.smoking_rooms_outlined,
    'debt' || 'loan' => Icons.currency_exchange_rounded,
    'internet' || 'wifi' => Icons.wifi_rounded,
    'subscription' || 'subscriptions' => Icons.subscriptions_rounded,
    'movie' || 'entertainment' => Icons.movie_outlined,
    'rent' || 'home' => Icons.home_work_outlined,
    'family' => Icons.family_restroom_rounded,
    'phone' || 'mobile' => Icons.phone_iphone_outlined,
    'utilities' => Icons.bolt_outlined,
    'drinks' || 'alcohol' => Icons.local_bar_outlined,
    'education' => Icons.school_outlined,
    'travel' => Icons.flight_outlined,
    'clothing' => Icons.checkroom_outlined,
    'personal' => Icons.person_outline_rounded,
    'pets' => Icons.pets_outlined,
    'account_balance_wallet' || 'salary' => CupertinoIcons.creditcard,
    'work' || 'freelance' => CupertinoIcons.briefcase,
    'card_giftcard' || 'gift' => CupertinoIcons.gift,
    'savings' => CupertinoIcons.money_dollar_circle,
    _ => CupertinoIcons.square_grid_2x2,
  };
}

String categoryIconLabel(String key) {
  return switch (key) {
    'restaurant' => 'Food',
    'directions_bus' => 'Transport',
    'shopping_bag' => 'Shopping',
    'receipt_long' => 'Bills',
    'medical_services' => 'Health',
    'cigarettes' => 'Cigarettes',
    'debt' => 'Debt or loan',
    'internet' => 'Internet',
    'subscription' => 'Subscription',
    'movie' => 'Movie or entertainment',
    'rent' => 'Rent or home',
    'family' => 'Family',
    'phone' => 'Phone',
    'utilities' => 'Utilities',
    'drinks' => 'Drinks',
    'education' => 'Education',
    'travel' => 'Travel',
    'clothing' => 'Clothing',
    'personal' => 'Personal care',
    'pets' => 'Pets',
    'account_balance_wallet' => 'Salary or wallet',
    'work' => 'Work or freelance',
    'card_giftcard' => 'Gift',
    'savings' => 'Savings',
    _ => 'Other',
  };
}
