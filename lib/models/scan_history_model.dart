class ScanHistoryModel {
  final String code;
  final String type;
  final String date;
  final String product;

  ScanHistoryModel({
    required this.code,
    required this.type,
    required this.date,
    required this.product,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': type,
      'date': date,
      'product': product,
    };
  }

  factory ScanHistoryModel.fromMap(Map<String, dynamic> map) {
    return ScanHistoryModel(
      code: map['code'],
      type: map['type'],
      date: map['date'],
      product: map['product'],
    );
  }
}