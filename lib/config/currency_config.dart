/// 国家/地区 → 货币 的集中配置中心。
///
/// 新增/修改国家与货币映射，只需要编辑本文件的 `kCurrencies` 与 `kRegions`：
///  - kCurrencies：货币定义（符号、名称、小数位、分组/小数分隔符、符号位置）
///  - kRegions：国家/地区定义（ISO 3166-1 两位代码 → 货币代码）
/// 未配置的国家/地区统一回退到 `kDefaultCurrencyCode`。
///
/// 本文件只负责「展示层」的符号/名称/格式，不参与任何金额计算与存储：
/// 数据库里保存的始终是 `double` 数值，换货币只影响显示。
library;

/// 默认货币：未配置的国家/地区使用。
const String kDefaultCurrencyCode = 'CNY';

/// 一种货币的展示定义。
class CurrencyDef {
  final String code; // ISO 4217，如 CNY / USD / EUR
  final String symbol; // 展示符号，如 ¥ / $ / €
  final String nameZh;
  final String nameEn;
  final int decimals; // 小数位数
  final String groupSeparator; // 千位分隔符
  final String decimalSeparator; // 小数点
  final bool symbolBefore; // 符号在数字前（false 则显示为「数字 符号」）

  const CurrencyDef({
    required this.code,
    required this.symbol,
    required this.nameZh,
    required this.nameEn,
    this.decimals = 2,
    this.groupSeparator = ',',
    this.decimalSeparator = '.',
    this.symbolBefore = true,
  });

  String name(bool isZh) => isZh ? nameZh : nameEn;

  /// 按本货币习惯格式化金额：¥1,234.50 / 1.234,50 € / ¥123,456
  String format(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && groupSeparator.isNotEmpty &&
          (intPart.length - i) % 3 == 0) {
        grouped.write(groupSeparator);
      }
      grouped.write(intPart[i]);
    }
    var number = grouped.toString();
    if (parts.length > 1 && decimals > 0) {
      number += decimalSeparator + parts[1];
    }
    final sign = negative ? '-' : '';
    return symbolBefore
        ? '$sign$symbol$number'
        : '$sign$number $symbol';
  }

  @override
  String toString() => '$code $symbol';
}

/// 全部受支持的货币。集中维护，便于后续新增或修改。
const Map<String, CurrencyDef> kCurrencies = {
  'CNY': CurrencyDef(code: 'CNY', symbol: '¥', nameZh: '人民币', nameEn: 'Chinese Yuan'),
  'USD': CurrencyDef(code: 'USD', symbol: '\$', nameZh: '美元', nameEn: 'US Dollar'),
  'HKD': CurrencyDef(code: 'HKD', symbol: 'HK\$', nameZh: '港元', nameEn: 'Hong Kong Dollar'),
  'MOP': CurrencyDef(code: 'MOP', symbol: 'MOP\$', nameZh: '澳门元', nameEn: 'Macao Pataca'),
  'TWD': CurrencyDef(code: 'TWD', symbol: 'NT\$', nameZh: '新台币', nameEn: 'New Taiwan Dollar', decimals: 0),
  'EUR': CurrencyDef(code: 'EUR', symbol: '€', nameZh: '欧元', nameEn: 'Euro', groupSeparator: '.', decimalSeparator: ',', symbolBefore: false),
  'GBP': CurrencyDef(code: 'GBP', symbol: '£', nameZh: '英镑', nameEn: 'Pound Sterling'),
  'JPY': CurrencyDef(code: 'JPY', symbol: '¥', nameZh: '日元', nameEn: 'Japanese Yen', decimals: 0),
  'KRW': CurrencyDef(code: 'KRW', symbol: '₩', nameZh: '韩元', nameEn: 'South Korean Won', decimals: 0),
  'SGD': CurrencyDef(code: 'SGD', symbol: 'S\$', nameZh: '新加坡元', nameEn: 'Singapore Dollar'),
  'MYR': CurrencyDef(code: 'MYR', symbol: 'RM', nameZh: '马来西亚林吉特', nameEn: 'Malaysian Ringgit'),
  'THB': CurrencyDef(code: 'THB', symbol: '฿', nameZh: '泰铢', nameEn: 'Thai Baht'),
  'VND': CurrencyDef(code: 'VND', symbol: '₫', nameZh: '越南盾', nameEn: 'Vietnamese Dong', decimals: 0, symbolBefore: false),
  'IDR': CurrencyDef(code: 'IDR', symbol: 'Rp', nameZh: '印尼盾', nameEn: 'Indonesian Rupiah', decimals: 0),
  'PHP': CurrencyDef(code: 'PHP', symbol: '₱', nameZh: '菲律宾比索', nameEn: 'Philippine Peso'),
  'INR': CurrencyDef(code: 'INR', symbol: '₹', nameZh: '印度卢比', nameEn: 'Indian Rupee'),
  'PKR': CurrencyDef(code: 'PKR', symbol: '₨', nameZh: '巴基斯坦卢比', nameEn: 'Pakistani Rupee'),
  'BDT': CurrencyDef(code: 'BDT', symbol: '৳', nameZh: '孟加拉塔卡', nameEn: 'Bangladeshi Taka'),
  'LKR': CurrencyDef(code: 'LKR', symbol: 'Rs', nameZh: '斯里兰卡卢比', nameEn: 'Sri Lankan Rupee'),
  'NPR': CurrencyDef(code: 'NPR', symbol: 'रू', nameZh: '尼泊尔卢比', nameEn: 'Nepalese Rupee'),
  'AUD': CurrencyDef(code: 'AUD', symbol: 'A\$', nameZh: '澳大利亚元', nameEn: 'Australian Dollar'),
  'NZD': CurrencyDef(code: 'NZD', symbol: 'NZ\$', nameZh: '新西兰元', nameEn: 'New Zealand Dollar'),
  'CAD': CurrencyDef(code: 'CAD', symbol: 'C\$', nameZh: '加拿大元', nameEn: 'Canadian Dollar'),
  'MXN': CurrencyDef(code: 'MXN', symbol: 'Mex\$', nameZh: '墨西哥比索', nameEn: 'Mexican Peso'),
  'BRL': CurrencyDef(code: 'BRL', symbol: 'R\$', nameZh: '巴西雷亚尔', nameEn: 'Brazilian Real', groupSeparator: '.', decimalSeparator: ','),
  'ARS': CurrencyDef(code: 'ARS', symbol: 'AR\$', nameZh: '阿根廷比索', nameEn: 'Argentine Peso'),
  'CLP': CurrencyDef(code: 'CLP', symbol: 'CLP\$', nameZh: '智利比索', nameEn: 'Chilean Peso', decimals: 0),
  'COP': CurrencyDef(code: 'COP', symbol: 'COL\$', nameZh: '哥伦比亚比索', nameEn: 'Colombian Peso', decimals: 0),
  'RUB': CurrencyDef(code: 'RUB', symbol: '₽', nameZh: '俄罗斯卢布', nameEn: 'Russian Ruble', groupSeparator: ' ', decimalSeparator: ',', symbolBefore: false),
  'UAH': CurrencyDef(code: 'UAH', symbol: '₴', nameZh: '乌克兰格里夫纳', nameEn: 'Ukrainian Hryvnia', groupSeparator: ' ', decimalSeparator: ','),
  'PLN': CurrencyDef(code: 'PLN', symbol: 'zł', nameZh: '波兰兹罗提', nameEn: 'Polish Zloty', groupSeparator: ' ', decimalSeparator: ',', symbolBefore: false),
  'TRY': CurrencyDef(code: 'TRY', symbol: '₺', nameZh: '土耳其里拉', nameEn: 'Turkish Lira', groupSeparator: '.', decimalSeparator: ','),
  'CZK': CurrencyDef(code: 'CZK', symbol: 'Kč', nameZh: '捷克克朗', nameEn: 'Czech Koruna', groupSeparator: ' ', decimalSeparator: ',', symbolBefore: false),
  'SEK': CurrencyDef(code: 'SEK', symbol: 'kr', nameZh: '瑞典克朗', nameEn: 'Swedish Krona', groupSeparator: ' ', decimalSeparator: ',', symbolBefore: false),
  'NOK': CurrencyDef(code: 'NOK', symbol: 'kr', nameZh: '挪威克朗', nameEn: 'Norwegian Krone', groupSeparator: ' ', decimalSeparator: ',', symbolBefore: false),
  'DKK': CurrencyDef(code: 'DKK', symbol: 'kr', nameZh: '丹麦克朗', nameEn: 'Danish Krone', groupSeparator: '.', decimalSeparator: ',', symbolBefore: false),
  'CHF': CurrencyDef(code: 'CHF', symbol: 'CHF', nameZh: '瑞士法郎', nameEn: 'Swiss Franc', groupSeparator: "'", decimalSeparator: '.'),
  'ILS': CurrencyDef(code: 'ILS', symbol: '₪', nameZh: '以色列新谢克尔', nameEn: 'Israeli New Shekel'),
  'AED': CurrencyDef(code: 'AED', symbol: 'د.إ', nameZh: '阿联酋迪拉姆', nameEn: 'UAE Dirham'),
  'SAR': CurrencyDef(code: 'SAR', symbol: '﷼', nameZh: '沙特里亚尔', nameEn: 'Saudi Riyal'),
  'ZAR': CurrencyDef(code: 'ZAR', symbol: 'R', nameZh: '南非兰特', nameEn: 'South African Rand'),
  'EGP': CurrencyDef(code: 'EGP', symbol: 'E£', nameZh: '埃及镑', nameEn: 'Egyptian Pound'),
  'NGN': CurrencyDef(code: 'NGN', symbol: '₦', nameZh: '尼日利亚奈拉', nameEn: 'Nigerian Naira'),
  'KES': CurrencyDef(code: 'KES', symbol: 'KSh', nameZh: '肯尼亚先令', nameEn: 'Kenyan Shilling'),
};

/// 一个国家/地区的定义。
class RegionDef {
  final String code; // ISO 3166-1 alpha-2（大写）
  final String nameZh;
  final String nameEn;
  final String currencyCode;

  const RegionDef({
    required this.code,
    required this.nameZh,
    required this.nameEn,
    required this.currencyCode,
  });

  String name(bool isZh) => isZh ? nameZh : nameEn;
}

/// 国家/地区 → 货币映射。顺序即设置页展示顺序（常用在前）。
///
/// 注意：中国香港 / 中国澳门 / 中国台湾 均为中国的一部分，
/// 这里按「国家/地区」口径列出，仅用于选择货币，不代表国家属性。
const List<RegionDef> kRegions = [
  RegionDef(code: 'CN', nameZh: '中国', nameEn: 'China', currencyCode: 'CNY'),
  RegionDef(code: 'HK', nameZh: '中国香港', nameEn: 'Hong Kong, China', currencyCode: 'HKD'),
  RegionDef(code: 'MO', nameZh: '中国澳门', nameEn: 'Macao, China', currencyCode: 'MOP'),
  RegionDef(code: 'TW', nameZh: '中国台湾', nameEn: 'Taiwan, China', currencyCode: 'TWD'),
  RegionDef(code: 'US', nameZh: '美国', nameEn: 'United States', currencyCode: 'USD'),
  RegionDef(code: 'GB', nameZh: '英国', nameEn: 'United Kingdom', currencyCode: 'GBP'),
  RegionDef(code: 'DE', nameZh: '德国', nameEn: 'Germany', currencyCode: 'EUR'),
  RegionDef(code: 'FR', nameZh: '法国', nameEn: 'France', currencyCode: 'EUR'),
  RegionDef(code: 'IT', nameZh: '意大利', nameEn: 'Italy', currencyCode: 'EUR'),
  RegionDef(code: 'ES', nameZh: '西班牙', nameEn: 'Spain', currencyCode: 'EUR'),
  RegionDef(code: 'NL', nameZh: '荷兰', nameEn: 'Netherlands', currencyCode: 'EUR'),
  RegionDef(code: 'BE', nameZh: '比利时', nameEn: 'Belgium', currencyCode: 'EUR'),
  RegionDef(code: 'AT', nameZh: '奥地利', nameEn: 'Austria', currencyCode: 'EUR'),
  RegionDef(code: 'PT', nameZh: '葡萄牙', nameEn: 'Portugal', currencyCode: 'EUR'),
  RegionDef(code: 'IE', nameZh: '爱尔兰', nameEn: 'Ireland', currencyCode: 'EUR'),
  RegionDef(code: 'FI', nameZh: '芬兰', nameEn: 'Finland', currencyCode: 'EUR'),
  RegionDef(code: 'GR', nameZh: '希腊', nameEn: 'Greece', currencyCode: 'EUR'),
  RegionDef(code: 'JP', nameZh: '日本', nameEn: 'Japan', currencyCode: 'JPY'),
  RegionDef(code: 'KR', nameZh: '韩国', nameEn: 'South Korea', currencyCode: 'KRW'),
  RegionDef(code: 'SG', nameZh: '新加坡', nameEn: 'Singapore', currencyCode: 'SGD'),
  RegionDef(code: 'MY', nameZh: '马来西亚', nameEn: 'Malaysia', currencyCode: 'MYR'),
  RegionDef(code: 'TH', nameZh: '泰国', nameEn: 'Thailand', currencyCode: 'THB'),
  RegionDef(code: 'VN', nameZh: '越南', nameEn: 'Vietnam', currencyCode: 'VND'),
  RegionDef(code: 'ID', nameZh: '印度尼西亚', nameEn: 'Indonesia', currencyCode: 'IDR'),
  RegionDef(code: 'PH', nameZh: '菲律宾', nameEn: 'Philippines', currencyCode: 'PHP'),
  RegionDef(code: 'IN', nameZh: '印度', nameEn: 'India', currencyCode: 'INR'),
  RegionDef(code: 'PK', nameZh: '巴基斯坦', nameEn: 'Pakistan', currencyCode: 'PKR'),
  RegionDef(code: 'BD', nameZh: '孟加拉国', nameEn: 'Bangladesh', currencyCode: 'BDT'),
  RegionDef(code: 'LK', nameZh: '斯里兰卡', nameEn: 'Sri Lanka', currencyCode: 'LKR'),
  RegionDef(code: 'NP', nameZh: '尼泊尔', nameEn: 'Nepal', currencyCode: 'NPR'),
  RegionDef(code: 'AU', nameZh: '澳大利亚', nameEn: 'Australia', currencyCode: 'AUD'),
  RegionDef(code: 'NZ', nameZh: '新西兰', nameEn: 'New Zealand', currencyCode: 'NZD'),
  RegionDef(code: 'CA', nameZh: '加拿大', nameEn: 'Canada', currencyCode: 'CAD'),
  RegionDef(code: 'MX', nameZh: '墨西哥', nameEn: 'Mexico', currencyCode: 'MXN'),
  RegionDef(code: 'BR', nameZh: '巴西', nameEn: 'Brazil', currencyCode: 'BRL'),
  RegionDef(code: 'AR', nameZh: '阿根廷', nameEn: 'Argentina', currencyCode: 'ARS'),
  RegionDef(code: 'CL', nameZh: '智利', nameEn: 'Chile', currencyCode: 'CLP'),
  RegionDef(code: 'CO', nameZh: '哥伦比亚', nameEn: 'Colombia', currencyCode: 'COP'),
  RegionDef(code: 'RU', nameZh: '俄罗斯', nameEn: 'Russia', currencyCode: 'RUB'),
  RegionDef(code: 'UA', nameZh: '乌克兰', nameEn: 'Ukraine', currencyCode: 'UAH'),
  RegionDef(code: 'PL', nameZh: '波兰', nameEn: 'Poland', currencyCode: 'PLN'),
  RegionDef(code: 'TR', nameZh: '土耳其', nameEn: 'Turkey', currencyCode: 'TRY'),
  RegionDef(code: 'CZ', nameZh: '捷克', nameEn: 'Czechia', currencyCode: 'CZK'),
  RegionDef(code: 'SE', nameZh: '瑞典', nameEn: 'Sweden', currencyCode: 'SEK'),
  RegionDef(code: 'NO', nameZh: '挪威', nameEn: 'Norway', currencyCode: 'NOK'),
  RegionDef(code: 'DK', nameZh: '丹麦', nameEn: 'Denmark', currencyCode: 'DKK'),
  RegionDef(code: 'CH', nameZh: '瑞士', nameEn: 'Switzerland', currencyCode: 'CHF'),
  RegionDef(code: 'IL', nameZh: '以色列', nameEn: 'Israel', currencyCode: 'ILS'),
  RegionDef(code: 'AE', nameZh: '阿联酋', nameEn: 'United Arab Emirates', currencyCode: 'AED'),
  RegionDef(code: 'SA', nameZh: '沙特阿拉伯', nameEn: 'Saudi Arabia', currencyCode: 'SAR'),
  RegionDef(code: 'ZA', nameZh: '南非', nameEn: 'South Africa', currencyCode: 'ZAR'),
  RegionDef(code: 'EG', nameZh: '埃及', nameEn: 'Egypt', currencyCode: 'EGP'),
  RegionDef(code: 'NG', nameZh: '尼日利亚', nameEn: 'Nigeria', currencyCode: 'NGN'),
  RegionDef(code: 'KE', nameZh: '肯尼亚', nameEn: 'Kenya', currencyCode: 'KES'),
];

/// 按地区代码查定义；找不到返回 null。
RegionDef? regionByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  for (final r in kRegions) {
    if (r.code == upper) return r;
  }
  return null;
}

/// 按货币代码取定义；异常代码回退默认货币。
CurrencyDef currencyByCode(String? code) =>
    kCurrencies[code] ?? kCurrencies[kDefaultCurrencyCode]!;

/// 核心规则：地区 → 货币。未配置/空地区统一使用默认货币。
CurrencyDef currencyForCountry(
  String? countryCode, {
  String defaultCurrencyCode = kDefaultCurrencyCode,
}) {
  final region = regionByCode(countryCode);
  final code = region?.currencyCode ?? defaultCurrencyCode;
  return kCurrencies[code] ?? kCurrencies[kDefaultCurrencyCode]!;
}
