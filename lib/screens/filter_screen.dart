import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

enum FilterType { all, year, month, category }

class FilterScreen extends StatefulWidget {
  final List<Expense> expenses;
  final List<ExpenseCategory> customCategories;

  const FilterScreen({
    super.key,
    required this.expenses,
    required this.customCategories,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen>
    with SingleTickerProviderStateMixin {
  FilterType _filterType = FilterType.all;
  String? _expandedKey;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  List<ExpenseCategory> get _allCategories => [
    ...DefaultCategories.list,
    ...widget.customCategories,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _changeFilter(FilterType type) {
    if (_filterType == type) return;
    _animController.reverse().then((_) {
      setState(() {
        _filterType = type;
        _expandedKey = null;
      });
      _animController.forward();
    });
  }

  Map<String, List<Expense>> get _groupedData {
    switch (_filterType) {
      case FilterType.all:
        return {'全部': widget.expenses};
      case FilterType.year:
        final map = <String, List<Expense>>{};
        for (final e in widget.expenses) {
          final key = '${e.date.year}年';
          map.putIfAbsent(key, () => []).add(e);
        }
        return Map.fromEntries(
          map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
        );
      case FilterType.month:
        final map = <String, List<Expense>>{};
        for (final e in widget.expenses) {
          final key = '${e.date.year}年${e.date.month}月';
          map.putIfAbsent(key, () => []).add(e);
        }
        return Map.fromEntries(
          map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
        );
      case FilterType.category:
        final map = <String, List<Expense>>{};
        for (final e in widget.expenses) {
          final cat = _allCategories.firstWhere(
            (c) => c.id == e.categoryId,
            orElse: () => _allCategories.first,
          );
          map.putIfAbsent(cat.label, () => []).add(e);
        }
        return map;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('账单筛选'),
        centerTitle: true,
        toolbarHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: FadeTransition(opacity: _fadeAnim, child: _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 48,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment(-1 + _filterType.index * 0.667, 0),
            child: Container(
              width: (MediaQuery.of(context).size.width - 40) / 4,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              _buildTab('全部', FilterType.all),
              _buildTab('按年', FilterType.year),
              _buildTab('按月', FilterType.month),
              _buildTab('按分类', FilterType.category),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, FilterType type) {
    final selected = _filterType == type;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _changeFilter(type),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _groupedData;
    if (data.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
      );
    }

    if (_filterType == FilterType.all) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.expenses.length,
        itemBuilder: (ctx, i) => _buildExpenseItem(widget.expenses[i]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: data.length,
      itemBuilder: (ctx, i) {
        final key = data.keys.elementAt(i);
        final expenses = data[key]!;
        final income = expenses
            .where((e) => e.isIncome)
            .fold(0.0, (s, e) => s + e.amount);
        final expense = expenses
            .where((e) => !e.isIncome)
            .fold(0.0, (s, e) => s + e.amount);
        final isExpanded = _expandedKey == key;

        return Column(
          children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _expandedKey = isExpanded ? null : key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${expenses.length}笔记录',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '收入 ¥${income.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '支出 ¥${expense.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: expenses.map((e) => _buildExpenseItem(e)).toList(),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    final cat = _allCategories.firstWhere(
      (c) => c.id == expense.categoryId,
      orElse: () => _allCategories.first,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (expense.title.isNotEmpty)
                  Text(
                    expense.title,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(expense.date),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${expense.isIncome ? '+' : '-'}¥${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: expense.isIncome ? Colors.green : Colors.red[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
