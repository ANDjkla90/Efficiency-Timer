import 'package:intl/intl.dart';

/// 应用文案中心：同一份 key 提供中/英两套文案。
/// 页面通过 AppScope.strings(context) 获取，语言切换后自动重建。
class L10n {
  final bool isZh;
  const L10n(this.isZh);

  // ——— 通用 ———
  String get appTitle => isZh ? '驰马时记' : 'Chima TimeLog';
  String get tabHome => isZh ? '首页' : 'Home';
  String get tabRecords => isZh ? '账目' : 'Records';
  String get tabStats => isZh ? '统计' : 'Stats';
  String get tabMe => isZh ? '我的' : 'Me';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get delete => isZh ? '删除' : 'Delete';
  String get save => isZh ? '保存' : 'Save';
  String get confirm => isZh ? '继续' : 'Continue';
  String get noData => isZh ? '暂无数据' : 'No data';
  String get employer => isZh ? '雇主' : 'Employer';
  String get perHour => isZh ? '/小时' : '/hr';
  String get privacyLine => isZh
      ? '核心功能离线 · 数据仅存本机 · 零权限'
      : 'Fully offline · On-device only · Zero permissions';

  // ——— 首页 ———
  String get onboardingTitle =>
      isZh ? '欢迎使用「驰马时记」' : 'Welcome to Chima TimeLog';
  String get onboardingDesc => isZh
      ? '给小时工、日结工用的记账本：记一笔工时，自动算工钱。'
      : 'A simple ledger for hourly and daily workers: log your hours, pay is calculated for you.';
  String get onboardingFeature => isZh
      ? '日期、工时、时薪、加班、补贴，随手记'
      : 'Date, hours, rate, overtime and allowances — all in one place';
  String get startWork => isZh ? '开始记工' : 'Get Started';
  String get employerShort => isZh ? '雇主/账本' : 'Employers';
  String get todayWage => isZh ? '今日工资' : "Today's Pay";
  String get todayHours => isZh ? '今日工时' : "Today's Hours";
  String todayEntries(int n) =>
      isZh ? '今日 $n 笔记录' : '$n ${n == 1 ? 'entry' : 'entries'} today';
  String get monthIncome => isZh ? '本月收入' : 'This Month';
  String get totalIncome => isZh ? '累计收入' : 'Total Income';
  String get recordOne => isZh ? '记一笔工时' : 'Log Work Time';
  String get copyLast => isZh ? '复制上次' : 'Repeat Last';
  String get addEmployer => isZh ? '建雇主' : 'Add Employer';
  String get switchEmployer => isZh ? '切换雇主' : 'Switch Employer';
  String get recentWork => isZh ? '最近记工' : 'Recent Entries';
  String get allInRecords => isZh ? '全部账目在「账目」页' : 'All entries in the Records tab';
  String get noRecords => isZh ? '还没有记工记录' : 'No work records yet';
  String get noRecordsHint => isZh
      ? '点上面「记一笔工时」，几秒就能记好一天'
      : 'Tap "Log Work Time" above to add one in seconds';

  // ——— 记一笔 ———
  String get newRecord => isZh ? '记一笔' : 'New Entry';
  String get editRecord => isZh ? '编辑记录' : 'Edit Entry';
  String get selectEmployerSheet =>
      isZh ? '选择雇主 / 账本' : 'Select Employer';
  String get tapNewOrSelect => isZh ? '点这里新建或选择' : 'Tap to add or select';
  String get workTime => isZh ? '工作时间' : 'Work Time';
  String get workDate => isZh ? '工作日期' : 'Work Date';
  String get timeMethod => isZh ? '工时记法' : 'How to Enter';
  String get byTimeRange => isZh ? '起止时间' : 'Start & End';
  String get byManualHours => isZh ? '填工时' : 'Enter Hours';
  String get manualHoursLabel =>
      isZh ? '工时（小时，可填 2.5）' : 'Hours (e.g. 2.5)';
  String get startTime => isZh ? '开始时间' : 'Start Time';
  String get endTime => isZh ? '结束时间' : 'End Time';
  String get thisShift => isZh ? '本次工时' : 'Hours This Shift';
  String get wage => isZh ? '工钱' : 'Pay';
  String get hourlyWage =>
      isZh ? '小时工资（每小时）' : 'Hourly Rate (per hour)';
  String get overtimeHours =>
      isZh ? '加班时长（小时）' : 'Overtime (hours)';
  String get overtimeRate =>
      isZh ? '加班时薪（每小时）' : 'Overtime Rate (per hour)';
  String get subsidyLabel => isZh
      ? '补贴（餐补/车补/夜班等）'
      : 'Allowance (meal / transport / night)';
  String get jobOptional =>
      isZh ? '工种（可选，方便按工种查账）' : 'Job Type (optional, for filtering)';
  String get jobExample =>
      isZh ? '如：搬运、安装、保洁' : 'e.g. Moving, Installation, Cleaning';
  String get noteOptional => isZh ? '备注（可选）' : 'Note (optional)';
  String get breakLabel =>
      isZh ? '休息扣除（分钟）' : 'Break Deduction (min)';
  String get breakHint => isZh
      ? '午休、吃饭时间不算工钱，填上后自动从工时里扣掉'
      : 'Lunch or rest time is unpaid — it is subtracted from the shift';
  String get breakNone => isZh ? '不扣' : 'None';
  String toastBreakTooLong(int minutes) => isZh
      ? '休息扣除不能超过本班时长（$minutes 分钟）'
      : 'Break cannot exceed the shift ($minutes min)';
  String get rateSnapshotTag => isZh ? '本笔单价' : 'This entry';
  String get breakMark => isZh ? '休' : 'Off';
  String get minuteUnit => isZh ? '分钟' : 'min';
  /// 纯分钟写法：「90分钟」而不是「1小时30分」，快捷选项一行放得下
  String minutesShort(int m) => isZh ? '$m分钟' : '${m}m';
  String breakDeducted(String d) =>
      isZh ? '已扣休息 $d' : 'minus $d break';
  String get normalPay => isZh ? '正常工资' : 'Regular Pay';
  String get overtimePayLabel => isZh ? '加班费' : 'Overtime Pay';
  String get subsidyShort => isZh ? '补贴' : 'Allowance';
  String get entryTotal => isZh ? '本笔合计' : 'Entry Total';
  String get saveEntry => isZh ? '保存这一笔' : 'Save Entry';
  String get saveChanges => isZh ? '保存修改' : 'Save Changes';
  String get toastSelectEmployer =>
      isZh ? '请先选择雇主/账本' : 'Please select an employer first';
  String get toastRate => isZh ? '请填写单价' : 'Please enter the rate';
  String get toastTimeOrder =>
      isZh ? '结束时间要晚于开始时间' : 'End time must be after start time';
  String get toastHours => isZh ? '请填写正确的工时' : 'Please enter valid hours';
  String get toastPieces =>
      isZh ? '请填写件数' : 'Please enter how many pieces';
  String get daysLabel => isZh ? '天数（1 天 = 一份日薪）' : 'Days (1 = one day\'s pay)';
  String get piecesLabel => isZh ? '件数' : 'Pieces';
  String get dailyHint => isZh
      ? '日薪按天算：天数 × 日薪，加班另算'
      : 'Daily pay = days × daily rate; overtime is added separately';
  String get pieceHint => isZh
      ? '计件按件算：件数 × 件单价'
      : 'Piece pay = pieces × rate per piece';
  String daysCount(int n) => isZh ? '$n 天' : '${n}d';
  String piecesCount(int n) => isZh ? '$n 件' : '$n pcs';
  String get perDay => isZh ? '/天' : '/day';
  String get perPiece => isZh ? '/件' : '/pc';

  List<String> get commonJobs => isZh
      ? const ['搬运', '安装', '保洁', '餐饮', '快递', '配送', '促销', '装修', '其他']
      : const [
          'Moving', 'Installation', 'Cleaning', 'Restaurant', 'Express',
          'Delivery', 'Promotion', 'Renovation', 'Other'
        ];

  // ——— 账目 ———
  String get records => isZh ? '账目' : 'Records';
  String get totalPrefix => isZh ? '共' : 'Total';
  String get byDate => isZh ? '按日期' : 'By Date';
  String get byEmployer => isZh ? '按雇主' : 'By Employer';
  String get byJob => isZh ? '按工种' : 'By Job';
  String get filterEmployer => isZh ? '雇主筛选' : 'Filter by Employer';
  String get allEmployers => isZh ? '全部雇主' : 'All Employers';
  String get filterJob => isZh ? '工种筛选' : 'Filter by Job Type';
  String get allJobs => isZh ? '全部工种' : 'All Job Types';
  String get filterRange => isZh ? '时间范围' : 'Date Range';
  String get rangeAll => isZh ? '全部' : 'All';
  String get rangeToday => isZh ? '今日' : 'Today';
  String get rangeWeek => isZh ? '本周' : 'This Week';
  String get rangeMonth => isZh ? '本月' : 'This Month';
  String get rangeCustom => isZh ? '自定义' : 'Custom';
  String rangeCustomSummary(String from, String to) =>
      isZh ? '$from 至 $to' : '$from – $to';
  String get rangeEmptyHint =>
      isZh ? '该时间范围内没有记录' : 'No records in this range';
  String get noRecordsHintRecords =>
      isZh ? '还没有账目，去首页记一笔吧' : 'No records yet — add one from Home';
  String get noFiltered =>
      isZh ? '该筛选下暂无记录' : 'No records match this filter';
  String get subtotal => isZh ? '小计' : 'Subtotal';
  String get uncategorized => isZh ? '未分类' : 'Uncategorized';
  String get noJobType => isZh ? '未填工种' : 'No job type';
  String get overtimeMark => isZh ? '加班' : 'OT';
  String get subsidyMark => isZh ? '补贴' : 'Allowance';
  String get deleteRecordTitle =>
      isZh ? '删除这笔记录？' : 'Delete this record?';
  String deleteRecordDesc(String amount) => isZh
      ? '删除后无法恢复。金额 $amount'
      : 'This cannot be undone. Amount: $amount';
  String get deleteSettledDesc => isZh
      ? '这笔已结算。删除后历史结算单金额不变，如需重算请先撤销结算。'
      : 'This entry is settled. The settlement total will not change; undo the settlement first if you need to recalculate.';
  String get deletedOne => isZh ? '已删除这笔记录' : 'Entry deleted';
  String get restoredOne => isZh ? '已恢复这笔记录' : 'Entry restored';
  String get undo => isZh ? '撤销' : 'Undo';
  String get settledTag => isZh ? '已结算' : 'Settled';
  String get swipeHint =>
      isZh ? '左滑删除，删错可撤销' : 'Swipe left to delete — undo is available';

  // ——— 统计 ———
  String get statsSummary => isZh ? '统计汇总' : 'Summary';
  String get totalHours => isZh ? '累计工时' : 'Total Hours';
  String get totalDays => isZh ? '累计天数' : 'Total Days';
  String get totalPieces => isZh ? '累计件数' : 'Total Pieces';
  String get hoursByType => isZh ? '按计薪方式汇总' : 'Totals by Pay Type';
  String get byEmployerStats => isZh ? '按雇主统计' : 'By Employer';
  String get byJobStats => isZh ? '按工种统计' : 'By Job Type';
  String get byMonthStats => isZh ? '按月统计' : 'By Month';
  String get today => isZh ? '今日' : 'Today';
  String get thisMonth => isZh ? '本月' : 'This Month';

  // ——— 雇主管理 ———
  String get employerManage => isZh ? '雇主 / 账本管理' : 'Employers & Ledgers';
  String get addEmployerHint =>
      isZh ? '点击右下角按钮添加雇主（账本）' : 'Tap + to add an employer';
  String get current => isZh ? '当前' : 'Current';
  String deleteLedgerTitle(String name) =>
      isZh ? '删除账本「$name」？' : 'Delete ledger "$name"?';
  String get deleteLedgerDesc => isZh
      ? '该账本下的所有工时记录会一起删除，且无法恢复。'
      : 'All work records under this ledger will also be deleted. This cannot be undone.';
  String get addEmployerSheet => isZh ? '添加雇主 / 账本' : 'Add Employer';
  String get editEmployerSheet => isZh ? '编辑雇主 / 账本' : 'Edit Employer';
  String get employerNameLabel => isZh
      ? '雇主/账本名称（如：张三工地）'
      : 'Employer name (e.g. Site A)';
  String get payMethod => isZh ? '计薪方式' : 'Pay Type';
  String get hourly => isZh ? '时薪' : 'Hourly';
  String get daily => isZh ? '日薪' : 'Daily';
  String get piece => isZh ? '计件' : 'Piece Rate';
  String get hourlyLabel =>
      isZh ? '小时工资（每小时）' : 'Hourly Rate (per hour)';
  String get dailyLabel => isZh ? '日薪（每天）' : 'Daily Rate (per day)';
  String get pieceLabel => isZh ? '件单价（每件）' : 'Rate per Piece';
  String get toastName => isZh ? '请填写账本名称' : 'Please enter a name';
  String get toastRateInvalid =>
      isZh ? '请填写正确的单价' : 'Please enter a valid rate';

  // ——— 设置 ———
  String get me => isZh ? '我的' : 'Me';
  String get exportBackup => isZh ? '导出数据备份' : 'Export Backup';
  String get exportSub =>
      isZh ? '保存到手机文件，不联网' : 'Saved to your device, never online';
  String get importBackup => isZh ? '导入数据备份' : 'Import Backup';
  String get importSub => isZh
      ? '从备份文件恢复（覆盖现有数据）'
      : 'Restore from a file (overwrites current data)';
  String get importDialogTitle => isZh ? '选择备份文件' : 'Select Backup File';
  String get backupFileNamePrefix =>
      isZh ? '驰马时记备份' : 'ChimaTimeLogBackup';
  String get privacy => isZh ? '隐私声明' : 'Privacy Policy';
  String get about => isZh ? '关于' : 'About';
  String get aboutSub => isZh
      ? '驰马时记 v3.2.1 · 记工 + 算账 + 查账 + 结算'
      : 'Chima TimeLog v3.2.1 · Log, Calculate, Review, Settle';
  String get importTitle => isZh ? '导入备份？' : 'Import backup?';
  String get importDesc => isZh
      ? '导入会覆盖当前所有数据，请确认已有重要数据已导出备份。'
      : 'Importing will overwrite all current data. Make sure you have exported a backup first.';
  String exportedTo(String path) =>
      isZh ? '已导出备份到：$path' : 'Backup exported to: $path';
  String restoredCount(int count) =>
      isZh ? '已恢复 $count 个账本' : 'Restored $count ledgers';
  String get importFailed => isZh
      ? '导入失败：文件已损坏，或不是「驰马时记」导出的备份'
      : 'Import failed: the file is damaged or not a Chima TimeLog backup';
  String get importReadFailed => isZh
      ? '读取文件失败，请换一个备份文件再试'
      : 'Could not read the file. Try another backup file.';
  String get exportFailed => isZh
      ? '导出失败，请检查存储空间后重试'
      : 'Export failed. Check free storage and try again.';

  // ——— 语言 / 主题设置 ———
  String get language => isZh ? '语言' : 'Language';
  String get themeColor => isZh ? '主题配色' : 'Theme Color';
  String get darkMode => isZh ? '深色模式' : 'Dark Mode';
  String get followSystem => isZh ? '跟随系统' : 'Follow System';
  String get chinese => isZh ? '简体中文' : 'Simplified Chinese';
  String get english => isZh ? 'English' : 'English';
  String get lightMode => isZh ? '浅色' : 'Light';
  String get darkModeOption => isZh ? '深色' : 'Dark';
  List<String> get themeColorNames => isZh
      ? const ['科技蓝', '活力绿', '暖阳橙', '热情红', '优雅紫']
      : const ['Tech Blue', 'Vital Green', 'Sunny Orange', 'Passion Red', 'Elegant Purple'];

  // ——— 国家/地区与货币 ———
  String get currencyRegion => isZh ? '国家 / 地区与货币' : 'Country / Region & Currency';
  String get currencyRegionTitle => isZh ? '选择国家 / 地区' : 'Select Country / Region';
  String get currencyDefaultTitle =>
      isZh ? '默认货币（未配置地区）' : 'Default currency (unconfigured)';
  String get currencyFollowSystem =>
      isZh ? '跟随系统地区（自动识别）' : 'Follow system region (auto)';
  String get currencyManual => isZh ? '手动选择' : 'Choose manually';
  String get currencyRegionHint => isZh
      ? '根据系统地区或你选择的地区，自动使用对应的货币符号与格式。'
      : 'Uses the matching currency symbol and format from your system region or your choice.';
  String get currencyDefaultHint => isZh
      ? '未配置的国家 / 地区统一使用此货币。'
      : 'Used for countries / regions without a configured currency.';
  String get currencyCurrent => isZh ? '当前生效' : 'Currently in effect';
  String get currencyPreview => isZh ? '显示示例' : 'Preview';
  String get currencySearchHint =>
      isZh ? '搜索国家 / 地区或货币' : 'Search country / region or currency';
  String currencyRegionSummary(String regionName, String currencyName, String symbol) =>
      isZh ? '$regionName · $currencyName $symbol' : '$regionName · $currencyName $symbol';
  String currencyUnconfigured(String code) =>
      isZh ? '未配置（$code）' : 'Unconfigured ($code)';
  String currencySystemRegion(String code) =>
      isZh ? '系统地区：$code' : 'System region: $code';

  // ——— 结算对账 ———
  String get settlements => isZh ? '结算对账' : 'Settlements';
  String get settlementSub => isZh
      ? '按周期把账目结清，可复制账单发给雇主'
      : 'Settle a period and copy the bill for your employer';
  String get settlementNew => isZh ? '生成结算单' : 'New Settlement';
  String get settlementThisMonth => isZh ? '本月' : 'This month';
  String get settlementLastMonth => isZh ? '上月' : 'Last month';
  String get settlementCustom => isZh ? '自定义' : 'Custom';
  String get settlementPeriod => isZh ? '结算周期' : 'Period';
  String get settlementPending => isZh ? '待结算' : 'To Settle';
  String settlementPendingSummary(int n, String amount) => isZh
      ? '$n 笔 · 合计 $amount'
      : '$n entries · $amount';
  String get settlementNonePending => isZh
      ? '该周期内没有未结算记录'
      : 'No unsettled entries in this period';
  String get settlementCreateTitle => isZh ? '生成结算单？' : 'Create settlement?';
  String settlementCreateDesc(int n, String amount) => isZh
      ? '把这 $n 笔记录（合计 $amount）标记为已结算，之后不会重复计入。'
      : 'Mark these $n entries ($amount) as settled so they are not counted twice.';
  String get settlementCreated => isZh ? '结算单已生成' : 'Settlement created';
  String get settlementHistory => isZh ? '历史结算单' : 'Settlement History';
  String get settlementEmpty =>
      isZh ? '还没有结算单，先在上方生成一张' : 'No settlements yet';
  String get settlementCopyBill => isZh ? '复制账单' : 'Copy Bill';
  String get settlementCopied =>
      isZh ? '账单已复制，可直接粘贴给雇主' : 'Bill copied — paste it to your employer';
  String get settlementRevoke => isZh ? '撤销结算' : 'Undo Settlement';
  String get settlementRevokeDesc => isZh
      ? '撤销后这些记录回到未结算状态，可以重新结算。'
      : 'These entries become unsettled again and can be settled anew.';
  String get settlementRevoked => isZh ? '已撤销结算' : 'Settlement undone';
  String settlementRecordCount(int n) =>
      isZh ? '$n 笔记录' : '$n entries';
  String get settlementNoEmployer =>
      isZh ? '先建一个雇主账本再结算' : 'Add an employer first';
  String get settlementSettledTag => isZh ? '已结清' : 'Settled';
  String settlementBillTitleLine(String employer) =>
      isZh ? '【结算单】$employer' : '[Settlement] $employer';
  String settlementBillPeriodLine(String from, String to) =>
      isZh ? '周期：$from 至 $to' : 'Period: $from – $to';
  String settlementBillCountLine(int n) =>
      isZh ? '共 $n 笔' : '$n entries';
  String settlementBillEntryLine(String date, String qty, String amount) =>
      isZh ? '$date  $qty  $amount' : '$date  $qty  $amount';
  String settlementBillTotalLine(String amount) =>
      isZh ? '合计应结：$amount' : 'Total: $amount';
  String get settlementBillFooter =>
      isZh ? '由「驰马时记」生成' : 'Generated by Chima TimeLog';

  // ——— 应用锁 ———
  String get appLock => isZh ? '应用锁' : 'App Lock';
  String appLockSummaryOn(int n) =>
      isZh ? '已开启 · $n 位 PIN' : 'On · $n-digit PIN';
  String get appLockSummaryOff =>
      isZh ? '用 PIN 保护本机账目' : 'Protect your records with a PIN';
  String get pinSetTitle => isZh ? '设置 PIN' : 'Set PIN';
  String get pinConfirmTitle => isZh ? '再输入一次' : 'Confirm PIN';
  String get pinUnlockTitle => isZh ? '输入 PIN 解锁' : 'Enter PIN';
  String get pinVerifyTitle => isZh ? '输入当前 PIN' : 'Enter current PIN';
  String get pinLengthTitle => isZh ? 'PIN 位数' : 'PIN Length';
  String get pin4 => isZh ? '4 位' : '4 digits';
  String get pin6 => isZh ? '6 位' : '6 digits';
  String get pinMismatch =>
      isZh ? '两次输入不一致，请重新设置' : 'PINs do not match, try again';
  String get pinWrong => isZh ? 'PIN 不正确' : 'Incorrect PIN';
  String pinThrottled(int seconds) => isZh
      ? 'PIN 不正确，请 $seconds 秒后再试'
      : 'Incorrect PIN. Try again in ${seconds}s';
  String get pinForgot => isZh ? '忘记 PIN？' : 'Forgot PIN?';
  String get pinForgotDesc => isZh
      ? 'PIN 只存在本机、无法找回。忘记只能卸载重装，本地数据会一起清除——'
          '请先在设置里「导出数据备份」留一份。'
      : 'The PIN is stored only on this device and cannot be recovered. '
          'Reinstalling clears local data, so export a backup first.';
  String get pinChanged => isZh ? 'PIN 已更新' : 'PIN updated';
  String get appLockEnabled => isZh ? '应用锁已开启' : 'App lock enabled';
  String get appLockDisabled => isZh ? '应用锁已关闭' : 'App lock disabled';
  String get pinChange => isZh ? '修改 PIN' : 'Change PIN';
  String get lockNow => isZh ? '立即锁定' : 'Lock Now';
  String get pinHintSet =>
      isZh ? '输入 4 或 6 位数字' : 'Enter 4 or 6 digits';
  String get pinCancel => isZh ? '取消' : 'Cancel';

  // ——— 隐私页 ———
  String get privacyTitle => isZh ? '隐私声明' : 'Privacy Policy';
  String get weDontCollect =>
      isZh ? '我们不收集任何数据' : 'We Collect No Data';
  String get noInternetTitle => isZh ? '不联网' : 'No Internet';
  String get noInternetDesc => isZh
      ? '本应用完全离线运行，不联网、不上传任何数据。APK 中不含网络权限，代码里没有任何网络请求。'
      : 'This app runs fully offline. The APK contains no network permission and the code makes no network requests.';
  String get noLoginTitle => isZh ? '无需注册登录' : 'No Sign-up Required';
  String get noLoginDesc =>
      isZh ? '不需要注册账号、不需要登录，打开就能用。' : 'No account, no sign-in. Just open and use it.';
  String get zeroPermTitle => isZh ? '零权限' : 'Zero Permissions';
  String get zeroPermDesc => isZh
      ? 'Manifest 中无任何权限声明：不申请网络、相机、相册、定位、存储、通讯录、通知等权限。'
      : 'No permissions declared in the Manifest at all: no network, camera, gallery, location, storage, contacts or notifications.';
  String get localOnlyTitle => isZh ? '数据只存在本机' : 'On-Device Only';
  String get localOnlyDesc => isZh
      ? '你的账本和工时记录只保存在这台手机的本地存储中，卸载应用即彻底清除。'
      : 'Your ledgers and work records live only in this phone\'s local storage and are removed when you uninstall.';
  String get backupControlTitle => isZh ? '备份由你掌控' : 'You Control Backups';
  String get backupControlDesc => isZh
      ? '你可以手动导出备份文件保存到自己指定的位置，是否保留完全由你决定。'
      : 'You can export a backup to a location of your choice. Keeping it is entirely up to you.';
  String get uninstallNote => isZh
      ? '如果你卸载本应用，所有数据将随之删除，无法找回。\n请在需要时提前手动导出备份。'
      : 'If you uninstall this app, all data will be deleted and cannot be recovered.\nExport a backup in advance if needed.';

  // ——— 开屏动画 ———
  String get splashSlogan => isZh ? '记工 · 算账 · 查账' : 'Log · Calculate · Review';
  String get splashDesc => isZh
      ? '小时工 · 日结工 都在用的记账本'
      : 'A ledger for hourly & daily workers';
  String get splashSkip => isZh ? '跳过' : 'Skip';
  List<String> get splashFeatures => isZh
      ? const ['一键记工时', '自动算工钱', '账目随时查']
      : const ['Log hours in a tap', 'Pay calculated for you', 'Check records anytime'];

  // ——— 格式化 ———
  static const List<String> _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// 完整日期：中文「2026年11月18日」/ 英文「Nov 18, 2026」
  String dateFull(DateTime d) => isZh
      ? DateFormat('yyyy年MM月dd日').format(d)
      : DateFormat('MMM d, yyyy').format(d);

  /// 短日期：中文「11月18日 09:00」/ 英文「Nov 18, 09:00」
  String dateShort(DateTime d) => isZh
      ? DateFormat('MM月dd日 HH:mm').format(d)
      : DateFormat('MMM d, HH:mm').format(d);

  /// 分组键（按日期查账用）
  String dateGroupKey(DateTime d) => isZh
      ? DateFormat('yyyy年MM月dd日').format(d)
      : DateFormat('yyyy-MM-dd').format(d);

  /// 只到日的短日期：中文「11月01日」/ 英文「Nov 1」（账单、筛选摘要用）
  String dateOnly(DateTime d) =>
      isZh ? DateFormat('MM月dd日').format(d) : DateFormat('MMM d').format(d);

  /// 月列表标题：支持备份里的 "2026-11" 形式
  String yearMonthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final month = int.tryParse(parts[1]);
    if (isZh) return '${parts[0]}年${parts[1]}月';
    if (month != null && month >= 1 && month <= 12) {
      return '${_enMonths[month - 1]} ${parts[0]}';
    }
    return '$key';
  }

  /// 时长：中文「9小时30分」/ 英文「9h 30m」
  String duration(int minutes) {
    if (minutes <= 0) return isZh ? '0分钟' : '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (isZh) {
      if (h == 0) return '${m}分钟';
      return m == 0 ? '${h}小时' : '${h}小时${m}分';
    }
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
