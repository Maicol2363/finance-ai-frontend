import '../../../../core/diagnostics/error_diagnostic.dart';
import '../domain/registration_models.dart';

enum RegistrationStatus { idle, submitting, failure, success }

class RegistrationState {
  const RegistrationState({
    this.status = RegistrationStatus.idle,
    this.fieldErrors = const {},
    this.generalError,
    this.diagnostic,
    this.result,
  });

  final RegistrationStatus status;
  final Map<String, List<String>> fieldErrors;
  final String? generalError;
  final ErrorDiagnostic? diagnostic;
  final RegistrationResult? result;

  bool get isSubmitting => status == RegistrationStatus.submitting;

  RegistrationState withoutFieldError(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    final nextErrors = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return RegistrationState(
      status: RegistrationStatus.idle,
      fieldErrors: Map.unmodifiable(nextErrors),
      generalError: generalError,
      diagnostic: diagnostic,
    );
  }
}

enum RegistrationSubmitOutcome { invalid, failure, success, ignored }
