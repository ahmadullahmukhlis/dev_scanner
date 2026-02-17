class ScanHistoryModel {
  int? id;
  final String code;
  final String type;
  final String date;
  final String product;

  ScanHistoryModel({
    this.id,
    required this.code,
    required this.type,
    required this.date,
    required this.product,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'type': type,
      'date': date,
      'product': product,
    };
  }

  factory ScanHistoryModel.fromMap(Map<String, dynamic> map) {
    return ScanHistoryModel(
      id: map['id'],
      code: map['code'],
      type: map['type'],
      date: map['date'],
      product: map['product'],
    );
  }
}