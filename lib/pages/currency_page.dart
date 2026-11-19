import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/pay_service.dart';
import '../theme.dart';

/// 国家/地区与货币设置页。
/// 映射集中在 currency_config.dart；这里只负责选择「跟随系统地区 / 手动地区」
/// 以及「未配置地区使用的默认货币」。所有改动即时生效并落盘。
class CurrencyPage extends StatelessWidget {
  const CurrencyPage({super.key});

  Future<void> _pickRegionSource(BuildContext context, L10n s) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.currencyRegionTitle),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              value: AppSettings.countryFollowSystem,
              groupValue: settings.countryMode,
              title: Text(s.currencyFollowSystem),
              subtitle: Text(s.currencySystemRegion(
                  settings.effectiveCountryCode.isEmpty
                      ? '--'
                      : settings.effectiveCountryCode)),
              onChanged: (v) {
                if (v != null) Navigator.pop(ctx, v);
              },
            ),
            RadioListTile<int>(
              value: AppSettings.countryManual,
              groupValue: settings.countryMode,
              title: Text(s.currencyManual),
              onChanged: (v) {
                if (v != null) Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked == AppSettings.countryFollowSystem) {
      await settings.setCountryMode(picked);
      return;
    }
    // 手动模式：选取具体国家/地区
    final code = await _showRegionPicker(context, s);
    if (code != null) {
      await settings.setCountryCode(code);
      await settings.setCountryMode(AppSettings.countryManual);
    }
  }

  Future<String?> _showRegionPicker(BuildContext context, L10n s) async {
    final controller = TextEditingController();
    final settings = AppSettings.instance;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final keyword = controller.text.trim().toLowerCase();
            final list = kRegions.where((r) {
              if (keyword.isEmpty) return true;
              final currency = currencyByCode(r.currencyCode);
              return r.code.toLowerCase().contains(keyword) ||
                  r.nameZh.contains(keyword) ||
                  r.nameEn.toLowerCase().contains(keyword) ||
                  currency.code.toLowerCase().contains(keyword) ||
                  currency.nameZh.contains(keyword) ||
                  currency.nameEn.toLowerCase().contains(keyword);
            }).toList();
            return AlertDialog(
              title: Text(s.currencyRegionTitle),
              contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: s.currencySearchHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final r = list[i];
                          final c = currencyByCode(r.currencyCode);
                          return RadioListTile<String>(
                            value: r.code,
                            groupValue: settings.countryMode == AppSettings.countryManual
                                ? settings.countryCode
                                : null,
                            title: Text(r.name(s.isZh)),
                            subtitle: Text('${c.code} · ${c.name(s.isZh)} ${c.symbol}'),
                            onChanged: (v) {
                              if (v != null) Navigator.pop(ctx, v);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickDefaultCurrency(BuildContext context, L10n s) async {
    final settings = AppSettings.instance;
    final codes = kCurrencies.keys.toList()..sort();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.currencyDefaultTitle),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: codes.length,
            itemBuilder: (_, i) {
              final c = currencyByCode(codes[i]);
              return RadioListTile<String>(
                value: c.code,
                groupValue: settings.defaultCurrencyCode,
                title: Text('${c.name(s.isZh)} (${c.code})'),
                subtitle: Text(PayService.moneyIn(1234.5, c)),
                onChanged: (v) {
                  if (v != null) Navigator.pop(ctx, v);
                },
              );
            },
          ),
        ),
      ),
    );
    if (picked != null) await settings.setDefaultCurrencyCode(picked);
  }

  String _regionName(L10n s, String code) {
    final region = regionByCode(code);
    if (region != null) return region.name(s.isZh);
    return s.currencyUnconfigured(code.isEmpty ? '--' : code);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final primary = Tones.primary(context);
    final settings = AppSettings.instance;
    final code = settings.effectiveCountryCode;
    final currency = settings.currency;
    final regionName = _regionName(s, code);
    final regionSource = settings.countryMode == AppSettings.countryManual
        ? s.currencyManual
        : s.currencyFollowSystem;

    return Scaffold(
      appBar: AppBar(title: Text(s.currencyRegion)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.currencyCurrent,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${currency.name(s.isZh)} · ${currency.code} ${currency.symbol}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Tones.primaryInk(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.currencyPreview}  ${PayService.moneyIn(1234.5, currency)}',
                    style: TextStyle(fontSize: 14, color: primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.public_outlined, color: primary),
                  title: Text(s.currencyRegion),
                  subtitle: Text('$regionSource · $regionName'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickRegionSource(context, s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance_outlined, color: primary),
                  title: Text(s.currencyDefaultTitle),
                  subtitle: Text(
                    '${currencyByCode(settings.defaultCurrencyCode).name(s.isZh)}'
                    ' · ${settings.defaultCurrencyCode}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickDefaultCurrency(context, s),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${s.currencyRegionHint}\n${s.currencyDefaultHint}',
              style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
