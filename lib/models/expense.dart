import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isCustom;

  const ExpenseCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'iconCode': icon.codePoint,
    'colorValue': color.toARGB32(),
    'isCustom': isCustom,
  };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseCategory(
        id: json['id'],
        label: json['label'],
        icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
        color: Color(json['colorValue']),
        isCustom: json['isCustom'] ?? false,
      );
}

class DefaultCategories {
  static const List<ExpenseCategory> list = [
    ExpenseCategory(
      id: 'takeout',
      label: '外卖',
      icon: Icons.delivery_dining,
      color: Color(0xFFFF6B6B),
    ),
    ExpenseCategory(
      id: 'transport',
      label: '公共交通',
      icon: Icons.directions_bus,
      color: Color(0xFF4ECDC4),
    ),
    ExpenseCategory(
      id: 'food',
      label: '美食',
      icon: Icons.restaurant,
      color: Color(0xFFFFE66D),
    ),
    ExpenseCategory(
      id: 'supermarket',
      label: '超市买菜',
      icon: Icons.local_grocery_store,
      color: Color(0xFF95E1D3),
    ),
    ExpenseCategory(
      id: 'online_grocery',
      label: '网上买菜',
      icon: Icons.shopping_basket,
      color: Color(0xFF7ED957),
    ),
    ExpenseCategory(
      id: 'shopping',
      label: '网购',
      icon: Icons.shopping_bag,
      color: Color(0xFFDDA0DD),
    ),
    ExpenseCategory(
      id: 'entertainment',
      label: '娱乐',
      icon: Icons.movie,
      color: Color(0xFF87CEEB),
    ),
    ExpenseCategory(
      id: 'tax',
      label: '税务五险',
      icon: Icons.account_balance,
      color: Color(0xFFFFA07A),
    ),
    ExpenseCategory(
      id: 'rent',
      label: '房租',
      icon: Icons.home,
      color: Color(0xFFB0B0B0),
    ),
    ExpenseCategory(
      id: 'utilities',
      label: '水电',
      icon: Icons.bolt,
      color: Color(0xFFFFD93D),
    ),
    ExpenseCategory(
      id: 'phone',
      label: '话费',
      icon: Icons.phone_android,
      color: Color(0xFF6BCB77),
    ),
    ExpenseCategory(
      id: 'haircut',
      label: '理发',
      icon: Icons.content_cut,
      color: Color(0xFFFF8C94),
    ),
    ExpenseCategory(
      id: 'taxi',
      label: '打车',
      icon: Icons.local_taxi,
      color: Color(0xFFFFB347),
    ),
    ExpenseCategory(
      id: 'gift',
      label: '送礼',
      icon: Icons.card_giftcard,
      color: Color(0xFFE57373),
    ),
    ExpenseCategory(
      id: 'fund',
      label: '基金',
      icon: Icons.trending_up,
      color: Color(0xFF64B5F6),
    ),
  ];

  static ExpenseCategory getById(
    String id,
    List<ExpenseCategory> customCategories,
  ) {
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      try {
        return customCategories.firstWhere((c) => c.id == id);
      } catch (_) {
        return list.first;
      }
    }
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final bool isIncome;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.isIncome = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date.toIso8601String(),
    'categoryId': categoryId,
    'isIncome': isIncome,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    title: json['title'] ?? '',
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date']),
    categoryId: json['categoryId'],
    isIncome: json['isIncome'] ?? false,
  );

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    bool? isIncome,
  }) => Expense(
    id: id ?? this.id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    categoryId: categoryId ?? this.categoryId,
    isIncome: isIncome ?? this.isIncome,
  );
}
