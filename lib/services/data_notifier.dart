import 'package:flutter/foundation.dart';

/// 全局数据变更通知器。
/// 任何数据增删改后调用 notify()，各页面监听并自动刷新，保证数据一致。
class DataNotifier extends ChangeNotifier {
  DataNotifier._();
  static final DataNotifier instance = DataNotifier._();

  void notify() => notifyListeners();
}
