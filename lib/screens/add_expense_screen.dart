import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../widgets/custom_dialog.dart';
import 'add_category_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;
  final List<ExpenseCategory> categories;
  final Map<String, int> categoryUsage;
  final Function(ExpenseCategory) onCategoryAdded;

  const AddExpenseScreen({
    super.key,
    this.expense,
    required this.categories,
    required this.categoryUsage,
    required this.onCategoryAdded,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late String _selectedCategoryId;
  late bool _isIncome;
  late DateTime _selectedDate;
  late Map<String, int> _categoryUsage;
  late List<ExpenseCategory> _categories;

  bool get _isEditing => widget.expense != null;

  ExpenseCategory get _selectedCategory =>
      _categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => _categories.first);

  String _getMostUsedCategoryId() {
    if (widget.categoryUsage.isEmpty) return _categories.first.id;
    final sorted = widget.categoryUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostUsedId = sorted.first.key;
    if (_categories.any((c) => c.id == mostUsedId)) {
      return mostUsedId;
    }
    return _categories.first.id;
  }

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _categoryUsage = Map.from(widget.categoryUsage);
    if (_isEditing) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _selectedCategoryId = widget.expense!.categoryId;
      _isIncome = widget.expense!.isIncome;
      _selectedDate = widget.expense!.date;
    } else {
      _selectedCategoryId = _getMostUsedCategoryId();
      _isIncome = false;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _calculateAmount() {
    String expr = _amountController.text.trim();
    if (expr.isEmpty) return null;
    try {
      expr = expr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
      final pattern = RegExp(r'^[\d.+\-*/]+$');
      if (pattern.hasMatch(expr)) {
        return _evalExpression(expr);
      }
      return double.tryParse(expr);
    } catch (_) {
      return double.tryParse(expr);
    }
  }

  double _evalExpression(String expr) {
    List<double> numbers = [];
    List<String> operators = [];
    String currentNum = '';
    
    for (int i = 0; i < expr.length; i++) {
      String c = expr[i];
      if ((c == '+' || c == '-' || c == '*' || c == '/') && currentNum.isNotEmpty) {
        numbers.add(double.parse(currentNum));
        currentNum = '';
        operators.add(c);
      } else if (c == '-' && currentNum.isEmpty) {
        currentNum = '-';
      } else {
        currentNum += c;
      }
    }
    if (currentNum.isNotEmpty) numbers.add(double.parse(currentNum));
    if (numbers.isEmpty) return 0;
    
    for (int i = 0; i < operators.length;) {
      if (operators[i] == '*' || operators[i] == '/') {
        numbers[i] = operators[i] == '*' ? numbers[i] * numbers[i + 1] : numbers[i] / numbers[i + 1];
        numbers.removeAt(i + 1);
        operators.removeAt(i);
      } else {
        i++;
      }
    }
    
    double result = numbers[0];
    for (int i = 0; i < operators.length; i++) {
      result = operators[i] == '+' ? result + numbers[i + 1] : result - numbers[i + 1];
    }
    return result;
  }

  void _submit() {
    final amount = _calculateAmount();
    if (amount == null || amount <= 0) {
      CustomDialog.showError(context, '请输入有效金额');
      return;
    }
    StorageService.incrementCategoryUsage(_selectedCategoryId);
    Navigator.pop(context, Expense(
      id: _isEditing ? widget.expense!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: amount,
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      isIncome: _isIncome,
    ));
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (mounted) {
        setState(() => _selectedDate = DateTime(
          date.year, date.month, date.day,
          time?.hour ?? _selectedDate.hour, time?.minute ?? _selectedDate.minute,
        ));
      }
    }
  }

  void _showCategoryPicker() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        categories: _categories,
        selectedId: _selectedCategoryId,
        categoryUsage: _categoryUsage,
        onSelected: (id) => Navigator.pop(ctx, id),
        onAddCategory: () => Navigator.pop(ctx, 'ADD_NEW'),
      ),
    );
    
    if (result == 'ADD_NEW') {
      final newCategory = await Navigator.push<ExpenseCategory>(
        context,
        MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
      );
      if (newCategory != null && mounted) {
        widget.onCategoryAdded(newCategory);
        setState(() {
          _categories.add(newCategory);
          _selectedCategoryId = newCategory.id;
        });
        _showCategoryPicker();
      }
    } else if (result != null && result is String) {
      setState(() => _selectedCategoryId = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(_isEditing ? '修改记录' : '添加记录'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeSelector(isIncome: _isIncome, onChanged: (v) => setState(() => _isIncome = v)),
            const SizedBox(height: 24),
            _buildAmountField(),
            const SizedBox(height: 16),
            _buildInputField('备注（选填）', _titleController, '请输入描述'),
            const SizedBox(height: 16),
            _buildDateSelector(),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('金额（支持加减运算）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '例如: 10+20 或 100',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final dateStr = '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日 '
        '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('时间', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(dateStr, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Icon(Icons.edit, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分类', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedCategory.color.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_selectedCategory.icon, color: _selectedCategory.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(_selectedCategory.label, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(_isEditing ? '保存修改' : '保存', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}


class _TypeSelector extends StatelessWidget {
  final bool isIncome;
  final ValueChanged<bool> onChanged;

  const _TypeSelector({required this.isIncome, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: isIncome ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: (MediaQuery.of(context).size.width - 48) / 2,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(false),
                  child: Center(
                    child: Text('支出', style: TextStyle(
                      fontWeight: !isIncome ? FontWeight.w600 : FontWeight.normal,
                      color: !isIncome ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                    )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(true),
                  child: Center(
                    child: Text('收入', style: TextStyle(
                      fontWeight: isIncome ? FontWeight.w600 : FontWeight.normal,
                      color: isIncome ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                    )),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String selectedId;
  final Map<String, int> categoryUsage;
  final Function(String) onSelected;
  final VoidCallback onAddCategory;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
    required this.categoryUsage,
    required this.onSelected,
    required this.onAddCategory,
  });

  List<ExpenseCategory> get _frequentCategories {
    final used = categories.where((c) => (categoryUsage[c.id] ?? 0) > 0).toList();
    used.sort((a, b) => (categoryUsage[b.id] ?? 0).compareTo(categoryUsage[a.id] ?? 0));
    return used.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final frequent = _frequentCategories;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择分类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (frequent.isNotEmpty) ...[
                  const Text('常用', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _CategoryGrid(categories: frequent, selectedId: selectedId, onSelected: onSelected),
                  const SizedBox(height: 20),
                ],
                const Text('全部分类', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 12),
                _CategoryGrid(categories: categories, selectedId: selectedId, onSelected: onSelected),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add),
                label: const Text('新建分类'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String selectedId;
  final Function(String) onSelected;

  const _CategoryGrid({required this.categories, required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((cat) => _CategoryItem(
        category: cat,
        isSelected: selectedId == cat.id,
        onTap: () => onSelected(cat.id),
      )).toList(),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ExpenseCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({required this.category, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: isSelected ? category.color.withAlpha(51) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? Border.all(color: category.color, width: 2) : null,
              ),
              child: Icon(category.icon, color: category.color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(category.label, style: TextStyle(fontSize: 12, color: Colors.grey[700]), 
              overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
