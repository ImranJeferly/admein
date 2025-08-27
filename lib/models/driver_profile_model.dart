class DriverProfileModel {
  final String driverFirstName;
  final String driverLastName;
  final String driverPhone;
  final String carBrand;
  final String carModel;
  final String currentStatus;
  final String carColor;
  final String carNormalizedNumber;
  final int carYear;
  final String? taxiParkName;
  final String? taxiParkPhone;

  DriverProfileModel({
    required this.driverFirstName,
    required this.driverLastName,
    required this.driverPhone,
    required this.carBrand,
    required this.carModel,
    required this.currentStatus,
    required this.carColor,
    required this.carNormalizedNumber,
    required this.carYear,
    this.taxiParkName,
    this.taxiParkPhone,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      driverFirstName: json['driverFirstName'] ?? '',
      driverLastName: json['driverLastName'] ?? '',
      driverPhone: json['driverPhone'] ?? '',
      carBrand: json['carBrand'] ?? '',
      carModel: json['carModel'] ?? '',
      currentStatus: json['currentStatus'] ?? '',
      carColor: json['carColor'] ?? '',
      carNormalizedNumber: json['carNormalizedNumber'] ?? '',
      carYear: json['carYear'] ?? 0,
      taxiParkName: json['taxiParkName'],
      taxiParkPhone: json['taxiParkPhone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverFirstName': driverFirstName,
      'driverLastName': driverLastName,
      'driverPhone': driverPhone,
      'carBrand': carBrand,
      'carModel': carModel,
      'currentStatus': currentStatus,
      'carColor': carColor,
      'carNormalizedNumber': carNormalizedNumber,
      'carYear': carYear,
      'taxiParkName': taxiParkName,
      'taxiParkPhone': taxiParkPhone,
    };
  }

  String get fullName => '$driverFirstName $driverLastName';
  String get fullCarModel => '$carBrand $carModel ($carYear)';
}