/// 时间计算工具：纯函数、不依赖 Flutter，便于单元测试直接覆盖。
///
/// 这里的逻辑是「记工时」的核心：夜班 22:00 → 06:00 必须算 8 小时，
/// 而不是 0 小时；结束时刻也必须落到次日，不能和开始时间同一天。
library;

/// 一天有多少分钟
const int minutesPerDay = 24 * 60;

/// 一天中的第几分钟（0 ~ 1439）
int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

/// 由时、分得到「一天中的第几分钟」
int clockMinutes(int hour, int minute) => hour * 60 + minute;

/// 两个钟点之间的分钟数；结束早于开始视为跨天。
///
/// 例：09:00 → 18:00 = 540；22:00 → 06:00 = 480；22:00 → 22:00 = 0。
/// 起止相同返回 0 而非 1440——手滑填成同一时刻时宁可拦住保存，
/// 也不要静默按 24 小时算出一笔离谱工钱（真上 24 小时班请用「填工时」）。
int minutesBetweenClocks(int startMinuteOfDay, int endMinuteOfDay) {
  final diff = endMinuteOfDay - startMinuteOfDay;
  if (diff > 0) return diff;
  if (diff == 0) return 0;
  return diff + minutesPerDay;
}

/// 该班次是否跨越午夜（结束钟点早于开始钟点）
bool crossesMidnight(int startMinuteOfDay, int endMinuteOfDay) =>
    endMinuteOfDay < startMinuteOfDay;

/// 扣除休息后的计薪分钟数。
///
/// 例：09:00 → 18:00（540 分钟）午休 60 分钟 = 480 分钟。
/// 休息填得比班次还长时按 0 处理，宁可算出 0 小时也不出现负工资；
/// 页面在保存前会先拦一道，不允许这种输入落库。
int paidMinutes(int spanMinutes, int breakMinutes) {
  if (spanMinutes <= 0) return 0;
  final paid = spanMinutes - (breakMinutes < 0 ? 0 : breakMinutes);
  return paid < 0 ? 0 : paid;
}

/// 日期 + 起始钟点 → 精确开始时刻
DateTime startOfDayClock(DateTime day, int startMinuteOfDay) =>
    DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: startMinuteOfDay));

/// 按「起止时间」记法算出精确起止时刻；跨天时结束时刻自动落到次日。
({DateTime start, DateTime end}) rangeFromClock(
  DateTime day,
  int startMinuteOfDay,
  int endMinuteOfDay,
) {
  final start = startOfDayClock(day, startMinuteOfDay);
  final minutes = minutesBetweenClocks(startMinuteOfDay, endMinuteOfDay);
  return (start: start, end: start.add(Duration(minutes: minutes)));
}

/// 按「填工时」记法算出精确起止时刻：结束时刻由开始时刻 + 时长推出，
/// 保证 endTime 与 durationMinutes 永远一致。
({DateTime start, DateTime end}) rangeFromDuration(
  DateTime day,
  int startMinuteOfDay,
  int durationMinutes,
) {
  final start = startOfDayClock(day, startMinuteOfDay);
  return (
    start: start,
    end: start.add(Duration(minutes: durationMinutes < 0 ? 0 : durationMinutes)),
  );
}
