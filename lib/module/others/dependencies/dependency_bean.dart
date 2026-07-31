

class DependencyBean {
  String? sId;
  String? mustId;
  int? id;
  int? created;
  String? createdAt;
  int? status;
  int? type;
  String? timestamp;
  String? name;
  List<String>? log;
  String? remark;

  DependencyBean(
      {this.sId,
      this.created,
      this.status,
      this.type,
      this.timestamp,
      this.name,
      this.log,
      this.remark});

  DependencyBean.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    id = json['id'];
    mustId = sId ?? (id?.toString() ?? "");
    created = int.tryParse(json['created'].toString());
    createdAt = json['createdAt'];
    status = json['status'];
    type = json['type'];
    timestamp = json['timestamp'].toString();
    name = json['name'];
    log = json['log'].cast<String>();
    remark = json['remark'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['created'] = created;
    data['status'] = status;
    data['type'] = type;
    data['timestamp'] = timestamp;
    data['name'] = name;
    data['log'] = log;
    data['remark'] = remark;
    return data;
  }

  static DependencyBean jsonConversion(Map<String, dynamic> json) {
    return DependencyBean.fromJson(json);
  }
}
