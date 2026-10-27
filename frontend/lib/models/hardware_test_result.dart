// frontend/lib/models/hardware_test_result.dart

class HardwareTestResult {
  final String testName;
  final String status; // 'passed' (موفق), 'failed' (نیازمند بررسی), 'info' (یادداشت)
  final String details;
  final DateTime timestamp;

  const HardwareTestResult({
    required this.testName,
    required this.status,
    required this.details,
    required this.timestamp,
  });

  bool get isPassed => status == 'passed';
  bool get isFailed => status == 'failed';

  String get localizedStatus {
    switch (status) {
      case 'passed':
        return 'موفق';
      case 'failed':
        return 'نیازمند بررسی';
      default:
        return 'یادداشت';
    }
  }

  Map<String, dynamic> toJson() => {
    'testName': testName,
    'status': status,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HardwareTestResult.fromJson(Map<String, dynamic> json) =>
      HardwareTestResult(
        testName: json['testName'] as String? ?? 'آزمون سخت‌افزار',
        status: json['status'] as String? ?? 'info',
        details: json['details'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
