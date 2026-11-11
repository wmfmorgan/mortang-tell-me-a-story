import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story/features/auth/presentation/sign_in_page.dart';
import 'package:tell_me_a_story/features/auth/data/otp_sign_in.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('landing copy, bad email, send failure, and a different email', (
    tester,
  ) async {
    final otp = _Otp();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SignInPage(otpSignIn: otp)));
    expect(find.text('Tell Me a Story'), findsOneWidget);
    expect(find.text(landingHeadline), findsOneWidget);
    expect(find.text(landingSubhead), findsOneWidget);
    expect(find.text('blackberry picking at the farm'), findsOneWidget);
    expect(find.text('summer, 1974'), findsOneWidget);
    expect(find.text('Sign in or get started'), findsOneWidget);
    expect(
      find.text('Enter your email to access your family archive.'),
      findsOneWidget,
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Email me a sign-in code'), findsOneWidget);
    expect(
      find.text("We'll email you a 6-digit code. No password needed."),
      findsOneWidget,
    );
    expect(
      find.text(
        'Private to your family. Stories stay inside the family you share them with.',
      ),
      findsOneWidget,
    );
    expect(find.text('Forgot password'), findsNothing);

    await tester.enterText(find.byKey(const Key('magic-link-email')), 'nope');
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Please enter a full email address.'), findsOneWidget);
    expect(otp.sent, isEmpty);

    otp.sendError = Exception('offline');
    await tester.enterText(find.byKey(const Key('magic-link-email')), 'a@b.co');
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);

    otp.sendError = null;
    await _tapText(tester, 'Email me a sign-in code');
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('We sent a 6-digit code to a@b.co.'), findsOneWidget);
    expect(find.text('Sign-in code'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-code')), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    final codeField = tester.widget<TextField>(
      find.byKey(const Key('sign-in-code')),
    );
    expect(codeField.decoration?.hintText, isNull);
    expect(otp.sent, ['a@b.co', 'a@b.co']);

    await _tapText(tester, 'Use a different email');
    expect(find.text('Sign in or get started'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });

  testWidgets('landing code step: errors, a new code, and sign-in', (
    tester,
  ) async {
    final otp = _Otp();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: SignInPage(otpSignIn: otp)));
    await tester.enterText(
      find.byKey(const Key('magic-link-email')),
      ' a@b.co ',
    );
    await _tapText(tester, 'Email me a sign-in code');
    expect(otp.sent, ['a@b.co']);

    for (final (reason, copy) in [
      (
        EmailAccountRequestExceptionReason.invalid,
        "That code isn't right. Check it and try again.",
      ),
      (
        EmailAccountRequestExceptionReason.expired,
        'That code has expired. Send a new one.',
      ),
      (
        EmailAccountRequestExceptionReason.tooManyAttempts,
        'Too many tries. Wait a few minutes, then send a new code.',
      ),
    ]) {
      otp.signInError = EmailAccountRequestException(reason: reason);
      await _enterCode(tester, '123456');
      expect(find.text(copy), findsOneWidget);
    }

    otp.signInError = null;
    await _tapText(tester, 'Send a new code');
    expect(otp.sent, ['a@b.co', 'a@b.co']);
    expect(
      find.text('Too many tries. Wait a few minutes, then send a new code.'),
      findsNothing,
    );
    expect(find.text('Check your email'), findsOneWidget);

    final pending = Completer<void>();
    otp.signInGate = pending;
    await tester.enterText(find.byKey(const Key('sign-in-code')), '111111');
    await tester.tap(find.byKey(const Key('sign-in-code-submit')));
    await tester.pump();
    expect(find.text('Signing in…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(otp.signIns.last, ('req-2', '111111'));
    expect(find.text('Sign in'), findsOneWidget);
  });
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('sign-in-code')), code);
  final submit = find.byKey(const Key('sign-in-code-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

class _Otp implements OtpSignIn {
  final sent = <String>[];
  final signIns = <(String, String)>[];
  Object? sendError;
  Object? signInError;
  Completer<void>? signInGate;
  void Function()? onSignIn;

  @override
  Future<String> sendCode(String email) async {
    sent.add(email);
    final error = sendError;
    if (error != null) throw error;
    return 'req-${sent.length}';
  }

  @override
  Future<void> signIn({required String requestId, required String code}) async {
    signIns.add((requestId, code));
    final gate = signInGate;
    if (gate != null) await gate.future;
    final error = signInError;
    if (error != null) throw error;
    onSignIn?.call();
  }
}
