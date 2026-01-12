import 'package:package_info_plus/package_info_plus.dart';
import 'package:expense_tracker/utils/request.dart';

class AppInfo {
  static String version = "";
  static bool isUpdata = false;
  static Future<void> getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
    final res = await dio
        .get(
          'https://gitee.com/master-dog/iaccounting-application/raw/master/version.json',
        )
        .catchError((e) {});
    if (res.data['version'] != packageInfo.version) {
      isUpdata = true;
    }
  }
}
