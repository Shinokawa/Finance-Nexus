import 'package:drift/drift.dart';

class EnumNameTypeConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumNameTypeConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) {
    return values.firstWhere((element) => element.name == fromDb);
  }

  @override
  String toSql(T value) {
    return value.name;
  }
}
