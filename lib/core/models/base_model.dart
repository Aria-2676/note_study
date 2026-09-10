/// Model 层数据序列化契约。
///
/// 所有需要与数据库交互的 Model 类应实现此 mixin，
/// 统一通过 [toDbMap] 序列化为数据库行（蛇形 key），
/// 避免散落的 [Map] 字面量造成字段名不一致。
mixin DbSerializable {
  /// 将当前实例序列化为数据库行映射。
  ///
  /// 所有 key 必须为蛇形命名（snake_case），
  /// 与数据库 schema 保持一致。
  Map<String, dynamic> toDbMap();
}
