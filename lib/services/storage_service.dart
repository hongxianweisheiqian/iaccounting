import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense.dart';

class StorageService {
  static const _expensesKey = 'expenses';
  static const _categoriesKey = 'custom_categories';
  static const _categoryUsageKey = 'category_usage';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<List<Expense>> loadExpenses() async {
    final p = await prefs;
    final data = p.getString(_expensesKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Expense.fromJson(e)).toList();
  }

  static Future<void> saveExpenses(List<Expense> expenses) async {
    final p = await prefs;
    final data = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await p.setString(_expensesKey, data);
  }

  static Future<List<ExpenseCategory>> loadCustomCategories() async {
    final p = await prefs;
    final data = p.getString(_categoriesKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => ExpenseCategory.fromJson(e)).toList();
  }

  static Future<void> saveCustomCategories(List<ExpenseCategory> categories) async {
    final p = await prefs;
    final data = jsonEncode(categories.map((e) => e.toJson()).toList());
    await p.setString(_categoriesKey, data);
  }

  static Future<Map<String, int>> loadCategoryUsage() async {
    final p = await prefs;
    final data = p.getString(_categoryUsageKey);
    if (data == null) return {};
    return Map<String, int>.from(jsonDecode(data));
  }

  static Future<void> saveCategoryUsage(Map<String, int> usage) async {
    final p = await prefs;
    await p.setString(_categoryUsageKey, jsonEncode(usage));
  }

  static Future<void> incrementCategoryUsage(String categoryId) async {
    final usage = await loadCategoryUsage();
    usage[categoryId] = (usage[categoryId] ?? 0) + 1;
    await saveCategoryUsage(usage);
  }

  static Future<void> clearAll() async {
    final p = await prefs;
    await p.remove(_expensesKey);
    await p.remove(_categoryUsageKey);
    await p.remove(_categoriesKey);
  }

  static Future<String?> exportExpenses(List<Expense> expenses, List<ExpenseCategory> customCategories, Map<String, int> categoryUsage) async {
    if (expenses.isEmpty) return '';
    
    try {
      final exportData = {
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'customCategories': customCategories.map((c) => c.toJson()).toList(),
        'categoryUsage': categoryUsage,
        'exportTime': DateTime.now().toIso8601String(),
      };
      final data = jsonEncode(exportData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'i_jizhang_$timestamp.json';
      
      // Android: 请求存储权限并保存到 Download 目录
      if (Platform.isAndroid) {
        // 请求存储权限
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final filePath = '${downloadDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(data);
          return filePath;
        }
      }
      
      // iOS/其他: 使用下载目录
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final filePath = '${downloadsDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(data);
        return filePath;
      }
      
      // 回退到外部存储目录
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final filePath = '${extDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(data);
        return filePath;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> importExpenses() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return null;
      
      final filePath = result.files.single.path;
      if (filePath == null) return null;
      
      final file = File(filePath);
      final data = await file.readAsString();
      final json = jsonDecode(data);
      
      if (json is Map<String, dynamic>) {
        if (json.containsKey('expenses')) {
          return json;
        }
      } else if (json is List) {
        return {'expenses': json, 'customCategories': [], 'categoryUsage': {}};
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
