// lib/models/job.dart

/// Model representing a job assigned to a worker.
class Job {
  final String id;
  final String jobNumber;
  final String companyName;
  final String status;
  final String? chalanNumber;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<JobStep> steps;

  Job({
    required this.id,
    required this.jobNumber,
    required this.companyName,
    required this.status,
    this.chalanNumber,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.steps,
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as String,
    jobNumber: json['jobNumber'] as String,
    companyName: json['companyName'] as String,
    status: json['status'] as String,
    chalanNumber: json['chalanNumber'] as String?,
    createdBy: json['createdBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    steps: (json['steps'] as List<dynamic>? ?? [])
        .map((e) => JobStep.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  int get totalSteps => steps.length;

  int get completedSteps =>
      steps.where((s) => s.status == JobStepStatus.completed).length;

  JobStep? get nextStep {
    try {
      return steps.firstWhere((s) => s.status != JobStepStatus.completed);
    } catch (_) {
      return null;
    }
  }
}

/// Model for a step inside a job.
class JobStep {
  final String id;
  final String stepName;
  final int stepOrder;
  final JobStepStatus status;
  final String? completedBy;
  final DateTime? completedAt;

  JobStep({
    required this.id,
    required this.stepName,
    required this.stepOrder,
    required this.status,
    this.completedBy,
    this.completedAt,
  });

  factory JobStep.fromJson(Map<String, dynamic> json) => JobStep(
    id: json['id'] as String,
    stepName: json['stepName'] as String,
    stepOrder: json['stepOrder'] as int,
    status: JobStepStatusExtension.fromString(json['status'] as String),
    completedBy: json['completedBy'] as String?,
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
  );
}

/// Typed status for a job step – matches backend enum values.
enum JobStepStatus { pending, inProgress, completed, cancelled }

extension JobStepStatusExtension on JobStepStatus {
  static JobStepStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return JobStepStatus.pending;
      case 'IN_PROGRESS':
        return JobStepStatus.inProgress;
      case 'COMPLETED':
        return JobStepStatus.completed;
      case 'CANCELLED':
        return JobStepStatus.cancelled;
      default:
        return JobStepStatus.pending;
    }
  }

  String get backendString {
    switch (this) {
      case JobStepStatus.pending:
        return 'PENDING';
      case JobStepStatus.inProgress:
        return 'IN_PROGRESS';
      case JobStepStatus.completed:
        return 'COMPLETED';
      case JobStepStatus.cancelled:
        return 'CANCELLED';
    }
  }
}
