import 'package:expense_tracker/utils/request.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../widgets/custom_dialog.dart';
import 'package:expense_tracker/config.dart';

class SettingsScreen extends StatelessWidget {
  final List<Expense> expenses;
  final List<ExpenseCategory> customCategories;
  final Map<String, int> categoryUsage;
  final VoidCallback onDataChanged;

  const SettingsScreen({
    super.key,
    required this.expenses,
    required this.customCategories,
    required this.categoryUsage,
    required this.onDataChanged,
  });

  Future<void> _exportData(BuildContext context) async {
    if (expenses.isEmpty) {
      CustomDialog.showError(context, '暂无流水记录，无法导出');
      return;
    }

    CustomDialog.showLoading(context, message: '正在导出账单...');
    await Future.delayed(const Duration(milliseconds: 500));
    final path = await StorageService.exportExpenses(
      expenses,
      customCategories,
      categoryUsage,
    );
    if (context.mounted) {
      CustomDialog.hideLoading(context);
      if (path != null && path.isNotEmpty) {
        // CustomDialog.showSuccess(context, '导出成功!\n文件位置: $path');
        CustomDialog.showSuccess(context, '导出成功!');
      } else {
        CustomDialog.showError(context, '导出失败');
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirm = await CustomDialog.showConfirm(
      context: context,
      title: '导入账单',
      message: '导入将覆盖现有所有账单数据，确定继续吗？',
      confirmText: '导入',
    );
    if (confirm != true) return;

    CustomDialog.showLoading(context, message: '正在导入账单...');
    await Future.delayed(const Duration(milliseconds: 500));
    final data = await StorageService.importExpenses();

    if (context.mounted) {
      CustomDialog.hideLoading(context);
      if (data != null) {
        final expensesList = (data['expenses'] as List)
            .map((e) => Expense.fromJson(e))
            .toList();
        final categoriesList =
            (data['customCategories'] as List?)
                ?.map((e) => ExpenseCategory.fromJson(e))
                .toList() ??
            [];
        final usageMap = Map<String, int>.from(data['categoryUsage'] ?? {});

        await StorageService.saveExpenses(expensesList);
        await StorageService.saveCustomCategories(categoriesList);
        await StorageService.saveCategoryUsage(usageMap);

        onDataChanged();
        CustomDialog.showSuccess(context, '成功导入 ${expensesList.length} 条记录');
      } else {
        CustomDialog.showError(context, '导入失败或已取消');
      }
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final confirm = await CustomDialog.showConfirm(
      context: context,
      title: '清除缓存',
      message: '确定要清除所有账单数据吗？此操作不可恢复！',
      confirmText: '清除',
    );
    if (confirm == true) {
      await StorageService.clearAll();
      onDataChanged();
      if (context.mounted) {
        CustomDialog.showSuccess(context, '已清除所有数据');
      }
    }
  }

  Future<void> _updataApp(BuildContext context) async {
    if (!AppInfo.isUpdata) return CustomDialog.showSuccess(context, '已是最新版本');
    final res = await dio
        .get(
          'https://gitee.com/master-dog/iaccounting-application/raw/master/version.json',
        )
        .catchError((e) {
          CustomDialog.showError(context, '更新失败！请稍后重试！');
        });
    if (context.mounted) {
      final confirm = await CustomDialog.showConfirm(
        context: context,
        title: '确认更新吗？',
        message: res.data['content'],
        confirmText: '更新',
      );
      if (confirm == true && context.mounted) {
        final installStatus = await Permission.requestInstallPackages
            .onDeniedCallback(() {
              return;
            })
            .onPermanentlyDeniedCallback(() {
              openAppSettings();
              return;
            })
            .request();
        if (installStatus == PermissionStatus.granted) {
          CustomDialog.showLoading(context, message: '正在更新...');
          final dir = await getTemporaryDirectory();
          String savePath = "${dir.path}/expense_tracker.apk";
          await dio.download(
            'https://gitee.com/master-dog/iaccounting-application/releases/download/v${res.data['version']}/app-arm64-v8a-release.apk',
            savePath,
            // onReceiveProgress: (received, total) {
            //   double _progress = received / total;
            //   //进度条
            //   // DownloadProgressOverlay().updateProgress(_progress);
            //   print('$_progress-进度');
            // },
          );
          CustomDialog.hideLoading(context);
          await OpenFile.open(savePath);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('数据管理', [
            _buildItem(
              Icons.file_upload_outlined,
              '导出账单',
              '文件一般保存在 Download 下',
              () => _exportData(context),
            ),
            _buildItem(
              Icons.file_download_outlined,
              '导入账单',
              '从JSON文件导入',
              () => _importData(context),
            ),
            _buildItem(
              Icons.delete_outline,
              '清除缓存',
              '删除所有账单数据',
              () => _clearData(context),
              isDestructive: true,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('关于', [
            _buildItem(
              Icons.info_outline,
              '版本${AppInfo.isUpdata ? ' (有更新)' : ''}',
              AppInfo.version,
              () => _updataApp(context),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}
