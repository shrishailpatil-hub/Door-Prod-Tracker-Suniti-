// lib/models/job_step_history.dart

/// Actions performed on a job or step.
enum JobStepAction { completed, undone, reopened, chalanAdded, jobCompleted }

extension JobStepActionExtension on JobStepAction {
  static JobStepAction fromString(String value) {
    switch (value.toUpperCase()) {
      case 'COMPLETED':
        return JobStepAction.completed;
      case 'UNDONE':
        return JobStepAction.undone;
      case 'REOPENED':
        return JobStepAction.reopened;
      case 'CHALAN_ADDED':
        return JobStepAction.chalanAdded;
      case 'JOB_COMPLETED':
        return JobStepAction.jobCompleted;
      default:
        throw ArgumentError('Unknown JobStepAction: $value');
    }
  }

  String get backendString {
    switch (this) {
      case JobStepAction.completed:
        return 'COMPLETED';
      case JobStepAction.undone:
        return 'UNDONE';
      case JobStepAction.reopened:
        return 'REOPENED';
      case JobStepAction.chalanAdded:
        return 'CHALAN_ADDED';
      case JobStepAction.jobCompleted:
        return 'JOB_COMPLETED';
    }
  }
}

/// Model representing a job step or job-level history event.
class JobStepHistory {
  final String id;
  final String jobId;
  final String? jobStepId;
  final String? stepName;
  final JobStepAction action;
  final String performedBy;
  final DateTime createdAt;

  JobStepHistory({
    required this.id,
    required this.jobId,
    this.jobStepId,
    this.stepName,
    required this.action,
    required this.performedBy,
    required this.createdAt,
  });

  factory JobStepHistory.fromJson(Map<String, dynamic> json) => JobStepHistory(
    id: json['id'] as String,
    jobId: json['jobId'] as String,
    jobStepId: json['jobStepId'] as String?,
    stepName: json['stepName'] as String?,
    action: JobStepActionExtension.fromString(json['action'] as String),
    performedBy: json['performedBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
