import 'package:get/get.dart';

import '../models/system_info.dart';

/// Session-scoped technician choices for the next software deployment.
///
/// Idle polling must never overwrite a choice the technician has just made.
/// Backend values become authoritative only while a queue is actually running;
/// activation consent is cleared once that observed queue finishes.
class DeploymentPreferences {
  final RxBool includeActivation = false.obs;
  final RxBool doubleSpeed = false.obs;

  bool _observedRunningQueue = false;

  void reconcileQueue(BatchInstallStatus status) {
    if (status.isRunning) {
      includeActivation.value = status.includeActivation;
      doubleSpeed.value = status.doubleSpeed;
      _observedRunningQueue = true;
      return;
    }

    if (_observedRunningQueue) {
      includeActivation.value = false;
      _observedRunningQueue = false;
    }
  }
}
