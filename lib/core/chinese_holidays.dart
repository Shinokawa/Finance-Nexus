/// 中国法定节假日工具类
/// 包含2024-2026年的法定节假日数据
class ChineseHolidays {
  ChineseHolidays._();

  /// 判断指定日期是否为交易日（工作日且非节假日）
  static bool isTradingDay(DateTime date) {
    // 周末不是交易日
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    // 检查是否为法定节假日
    final normalized = DateTime(date.year, date.month, date.day);
    return !_holidays.contains(normalized);
  }

  /// 2024-2026年的法定节假日列表
  /// 包括：元旦、春节、清明节、劳动节、端午节、中秋节、国庆节
  static final Set<DateTime> _holidays = {
    // 2024年
    DateTime(2024, 1, 1),  // 元旦
    DateTime(2024, 2, 10), // 春节（除夕）
    DateTime(2024, 2, 11), // 春节
    DateTime(2024, 2, 12), // 春节
    DateTime(2024, 2, 13), // 春节
    DateTime(2024, 2, 14), // 春节
    DateTime(2024, 2, 15), // 春节
    DateTime(2024, 2, 16), // 春节
    DateTime(2024, 2, 17), // 春节
    DateTime(2024, 4, 4),  // 清明节
    DateTime(2024, 4, 5),  // 清明节
    DateTime(2024, 4, 6),  // 清明节
    DateTime(2024, 5, 1),  // 劳动节
    DateTime(2024, 5, 2),  // 劳动节
    DateTime(2024, 5, 3),  // 劳动节
    DateTime(2024, 5, 4),  // 劳动节
    DateTime(2024, 5, 5),  // 劳动节
    DateTime(2024, 6, 10), // 端午节
    DateTime(2024, 9, 15), // 中秋节
    DateTime(2024, 9, 16), // 中秋节
    DateTime(2024, 9, 17), // 中秋节
    DateTime(2024, 10, 1), // 国庆节
    DateTime(2024, 10, 2), // 国庆节
    DateTime(2024, 10, 3), // 国庆节
    DateTime(2024, 10, 4), // 国庆节
    DateTime(2024, 10, 5), // 国庆节
    DateTime(2024, 10, 6), // 国庆节
    DateTime(2024, 10, 7), // 国庆节

    // 2025年
    DateTime(2025, 1, 1),  // 元旦
    DateTime(2025, 1, 28), // 春节（除夕）
    DateTime(2025, 1, 29), // 春节
    DateTime(2025, 1, 30), // 春节
    DateTime(2025, 1, 31), // 春节
    DateTime(2025, 2, 1),  // 春节
    DateTime(2025, 2, 2),  // 春节
    DateTime(2025, 2, 3),  // 春节
    DateTime(2025, 2, 4),  // 春节
    DateTime(2025, 4, 4),  // 清明节
    DateTime(2025, 4, 5),  // 清明节
    DateTime(2025, 4, 6),  // 清明节
    DateTime(2025, 5, 1),  // 劳动节
    DateTime(2025, 5, 2),  // 劳动节
    DateTime(2025, 5, 3),  // 劳动节
    DateTime(2025, 5, 4),  // 劳动节
    DateTime(2025, 5, 5),  // 劳动节
    DateTime(2025, 5, 31), // 端午节
    DateTime(2025, 6, 1),  // 端午节
    DateTime(2025, 6, 2),  // 端午节
    DateTime(2025, 10, 1), // 国庆节
    DateTime(2025, 10, 2), // 国庆节
    DateTime(2025, 10, 3), // 国庆节
    DateTime(2025, 10, 4), // 国庆节
    DateTime(2025, 10, 5), // 国庆节
    DateTime(2025, 10, 6), // 国庆节 + 中秋节
    DateTime(2025, 10, 7), // 国庆节
    DateTime(2025, 10, 8), // 国庆节

    // 2026年
    DateTime(2026, 1, 1),  // 元旦
    DateTime(2026, 1, 2),  // 元旦
    DateTime(2026, 1, 3),  // 元旦
    DateTime(2026, 2, 16), // 春节（除夕）
    DateTime(2026, 2, 17), // 春节
    DateTime(2026, 2, 18), // 春节
    DateTime(2026, 2, 19), // 春节
    DateTime(2026, 2, 20), // 春节
    DateTime(2026, 2, 21), // 春节
    DateTime(2026, 2, 22), // 春节
    DateTime(2026, 2, 23), // 春节
    DateTime(2026, 4, 4),  // 清明节
    DateTime(2026, 4, 5),  // 清明节
    DateTime(2026, 4, 6),  // 清明节
    DateTime(2026, 5, 1),  // 劳动节
    DateTime(2026, 5, 2),  // 劳动节
    DateTime(2026, 5, 3),  // 劳动节
    DateTime(2026, 5, 4),  // 劳动节
    DateTime(2026, 5, 5),  // 劳动节
    DateTime(2026, 6, 19), // 端午节
    DateTime(2026, 6, 20), // 端午节
    DateTime(2026, 6, 21), // 端午节
    DateTime(2026, 9, 25), // 中秋节
    DateTime(2026, 9, 26), // 中秋节
    DateTime(2026, 9, 27), // 中秋节
    DateTime(2026, 10, 1), // 国庆节
    DateTime(2026, 10, 2), // 国庆节
    DateTime(2026, 10, 3), // 国庆节
    DateTime(2026, 10, 4), // 国庆节
    DateTime(2026, 10, 5), // 国庆节
    DateTime(2026, 10, 6), // 国庆节
    DateTime(2026, 10, 7), // 国庆节
    DateTime(2026, 10, 8), // 国庆节
  };
}
