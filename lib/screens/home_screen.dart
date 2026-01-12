import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../widgets/expense_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/custom_dialog.dart';
import 'add_expense_screen.dart';
import 'filter_screen.dart';
import 'settings_screen.dart';
import 'package:expense_tracker/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> _expenses = [];
  List<ExpenseCategory> _customCategories = [];
  Map<String, int> _categoryUsage = {};
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    AppInfo.getVersion();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 300;
    if (shouldShow != _showBackToTop)
      setState(() => _showBackToTop = shouldShow);
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      StorageService.loadExpenses(),
      StorageService.loadCustomCategories(),
      StorageService.loadCategoryUsage(),
    ]);
    if (mounted) {
      setState(() {
        _expenses = (results[0] as List<Expense>)
          ..sort((a, b) => b.date.compareTo(a.date));
        _customCategories = results[1] as List<ExpenseCategory>;
        _categoryUsage = results[2] as Map<String, int>;
        _isLoading = false;
      });
    }
  }

  List<ExpenseCategory> get _allCategories => [
    ...DefaultCategories.list,
    ..._customCategories,
  ];

  List<Expense> get _currentMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }

  double get _totalExpense => _currentMonthExpenses
      .where((e) => !e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);
  double get _totalIncome => _currentMonthExpenses
      .where((e) => e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  Future<void> _addExpense() async {
    final result = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          categories: _allCategories,
          categoryUsage: _categoryUsage,
          onCategoryAdded: _onCategoryAdded,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _expenses.insert(0, result);
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      });
      await StorageService.saveExpenses(_expenses);
      _categoryUsage = await StorageService.loadCategoryUsage();
      if (mounted) setState(() {});
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          expense: expense,
          categories: _allCategories,
          categoryUsage: _categoryUsage,
          onCategoryAdded: _onCategoryAdded,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final index = _expenses.indexWhere((e) => e.id == result.id);
        if (index != -1) {
          _expenses[index] = result;
          _expenses.sort((a, b) => b.date.compareTo(a.date));
        }
      });
      await StorageService.saveExpenses(_expenses);
      _categoryUsage = await StorageService.loadCategoryUsage();
      if (mounted) setState(() {});
    }
  }

  void _onCategoryAdded(ExpenseCategory category) {
    setState(() => _customCategories.add(category));
    StorageService.saveCustomCategories(_customCategories);
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await CustomDialog.showConfirm(
      context: context,
      title: '确认删除',
      message: '确定要删除这条记录吗？',
      confirmText: '删除',
      cancelText: '取消',
    );
    if (confirmed == true) {
      setState(() => _expenses.removeWhere((e) => e.id == expense.id));
      await StorageService.saveExpenses(_expenses);
    }
  }

  void _openFilter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          expenses: _expenses,
          customCategories: _customCategories,
        ),
      ),
    );
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          expenses: _expenses,
          customCategories: _customCategories,
          categoryUsage: _categoryUsage,
          onDataChanged: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthExpenses = _currentMonthExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: const Color(0xFFF8FAFC),
                elevation: 0,
                title: const Text(
                  'I记账',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GestureDetector(
                    onTap: _openFilter,
                    child: SummaryCard(
                      totalExpense: _totalExpense,
                      totalIncome: _totalIncome,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: monthExpenses.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '本月暂无记录',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final expense = monthExpenses[index];
                          final category = DefaultCategories.getById(
                            expense.categoryId,
                            _customCategories,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ExpenseCard(
                              expense: expense,
                              category: category,
                              onTap: () => _editExpense(expense),
                              onDelete: () => _deleteExpense(expense),
                            ),
                          );
                        }, childCount: monthExpenses.length),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          // 回到顶部按钮
          Positioned(
            left: 16,
            bottom: 24,
            child: AnimatedScale(
              scale: _showBackToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton.small(
                heroTag: 'backToTop',
                onPressed: _scrollToTop,
                backgroundColor: Colors.white,
                child: const Icon(Icons.arrow_upward, color: Colors.black54),
              ),
            ),
          ),
          // 添加记录按钮
          Positioned(
            right: 16,
            bottom: 24,
            child: Opacity(
              opacity: 0.75,
              child: FloatingActionButton(
                heroTag: 'addExpense',
                onPressed: _addExpense,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
