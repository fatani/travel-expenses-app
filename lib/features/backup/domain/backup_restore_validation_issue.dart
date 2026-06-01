/// A single restore-gate validation failure.
class BackupRestoreValidationIssue {
  const BackupRestoreValidationIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Outcome of [BackupRestoreValidator.validate].
class BackupRestoreValidationResult {
  const BackupRestoreValidationResult._({
    required this.isValid,
    required this.issues,
  });

  factory BackupRestoreValidationResult.success() {
    return const BackupRestoreValidationResult._(isValid: true, issues: []);
  }

  factory BackupRestoreValidationResult.failure(
    List<BackupRestoreValidationIssue> issues,
  ) {
    return BackupRestoreValidationResult._(isValid: false, issues: issues);
  }

  final bool isValid;
  final List<BackupRestoreValidationIssue> issues;
}
