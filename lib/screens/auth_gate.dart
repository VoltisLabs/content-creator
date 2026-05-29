import 'package:flutter/material.dart';

import '../services/voltis_core_service.dart';
import '../state/app_settings.dart';
import 'auth/sign_in_screen.dart';

/// After splash: blocks the calendar until Voltis Core sign-in succeeds.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final voltis = VoltisCoreService.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final signedIn =
            settings.isSignedIn && voltis.isSignedIn && voltis.email != null;
        if (signedIn) {
          return child;
        }
        return const SignInScreen(embeddedInGate: true);
      },
    );
  }
}
