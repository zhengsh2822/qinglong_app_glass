
class EnvBean {
  String? name;
  String? value;
  String? remarks;
  int? status;
  String? sId;
  String? _id;
  int? id;
  int? created;
  String? timestamp;
  String? updatedAt;
  String? createdAt;

  EnvBean(
      {this.value,
      this.sId,
      this.created,
      this.status,
      this.timestamp,
      this.name,
      this.remarks});

  get nId => _id;

  EnvBean.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    value = json['value'];
    remarks = json['remarks'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    status = json['status'];
    id = json['id'];
    _id = json['_id'];
    sId = json.containsKey('_id')
        ? json['_id'].toString()
        : (json.containsKey('id') ? json['id'].toString() : "");
    created = int.tryParse(json['created'].toString());
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['value'] = value;
    data['remarks'] = remarks;
    data['status'] = status;
    data['_id'] = _id;
    data['id'] = id;
    data['created'] = created;
    data['timestamp'] = timestamp;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }

  static EnvBean jsonConversion(Map<String, dynamic> json) {
    return EnvBean.fromJson(json);
  }

  /// 搜索匹配（大小写不敏感）：关键词为空永远命中；命中 name/value/remarks
  /// 任一字段即算匹配。所有列表过滤共用此方法，避免各页面重复实现遗漏转小写。
  bool matchSearch(String keyword) {
    if (keyword.isEmpty) return true;
    final kw = keyword.toLowerCase();
    return (name?.toLowerCase().contains(kw) ?? false) ||
        (value?.toLowerCase().contains(kw) ?? false) ||
        (remarks?.toLowerCase().contains(kw) ?? false);
  }
}
