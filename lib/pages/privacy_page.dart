import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../theme.dart';

/// 隐私声明页：明示本应用不收集任何数据、不联网、不申请权限。
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final primary = Tones.primary(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.shield_outlined, size: 64, color: primary),
          const SizedBox(height: 16),
          Text(
            s.weDontCollect,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _item(Icons.wifi_off, s.noInternetTitle, s.noInternetDesc, primary),
          _item(Icons.no_accounts, s.noLoginTitle, s.noLoginDesc, primary),
          _item(Icons.phonelink_lock, s.zeroPermTitle, s.zeroPermDesc, primary),
          _item(Icons.save, s.localOnlyTitle, s.localOnlyDesc, primary),
          _item(Icons.backup, s.backupControlTitle, s.backupControlDesc, primary),
          const SizedBox(height: 24),
          Text(
            s.uninstallNote,
            style: const TextStyle(color: Colors.grey, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, String desc, Color primary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc,
                    style:
                        const TextStyle(color: Colors.grey, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
