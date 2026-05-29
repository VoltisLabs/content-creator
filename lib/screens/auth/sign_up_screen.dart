import 'package:flutter/material.dart';

import '../../services/voltis_core_service.dart';
import '../../state/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/auth_ambient_background.dart';
import '../../widgets/auth_centered_body.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    this.embeddedInGate = false,
  });

  final bool embeddedInGate;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _accept = false;

  final _voltis = VoltisCoreService.instance;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  ThemeData _authTheme(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark
        ? AppTheme.cursor
        : AppTheme.pinnacleClassic;
  }

  Future<void> _submit(AppSettings settings) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accept) {
      _snack('Please accept the terms to continue');
      return;
    }
    if (!_voltis.isConfigured) {
      _snack('Voltis Core is not configured on this build.');
      return;
    }
    setState(() => _busy = true);
    final message = await _voltis.signUpWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      _snack(message);
      if (message.contains('Check your email')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SignInScreen(embeddedInGate: widget.embeddedInGate),
          ),
        );
      }
      return;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final authTheme = _authTheme(context);

    return Theme(
      data: authTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final settings = AppSettingsScope.of(context);

          return AuthAmbientBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: widget.embeddedInGate
                  ? AppBar(backgroundColor: Colors.transparent)
                  : AppBar(
                      backgroundColor: Colors.transparent,
                      title: const Text('Create account'),
                    ),
              body: SafeArea(
                child: Form(
                  key: _formKey,
                  child: AuthCenteredBody(
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: theme.colorScheme.primaryContainer,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/icons/app_icon_mobile.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Create your account',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Uses Voltis Core. Your posts and images stay on this device.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.68),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                    core: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Add your name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Enter your email';
                            if (!s.contains('@') || !s.contains('.')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_rounded),
                            helperText: 'At least 6 characters',
                          ),
                          validator: (v) => (v ?? '').length < 6
                              ? 'Minimum 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _accept,
                              onChanged: (v) =>
                                  setState(() => _accept = v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I agree to the Content Calendar terms and privacy notice.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.72),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  AppHaptics.tap();
                                  _submit(settings);
                                },
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                      ],
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                AppHaptics.tap();
                                if (widget.embeddedInGate) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignInScreen(
                                        embeddedInGate: true,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Sign in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
