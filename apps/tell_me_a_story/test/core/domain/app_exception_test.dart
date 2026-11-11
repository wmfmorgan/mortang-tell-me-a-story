import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';

void main() {
  test('appErrorMessage reads only AppException', () {
    expect(
      appErrorMessage(
        const AppException(
          code: AppErrorCode.validation,
          message: 'Already linked',
        ),
      ),
      'Already linked',
    );
    expect(appErrorMessage(StateError('x')), isNull);
  });
}
