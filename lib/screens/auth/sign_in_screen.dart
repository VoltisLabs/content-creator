import 'package:flutter/material.dart';

import '../../services/voltis_core_service.dart';
import '../../state/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/auth_ambient_background.dart';
import '../../widgets/auth_centered_body.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.embeddedInGate = false,
  });

  final bool embeddedInGate;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  final _voltis = VoltisCoreService.instance;

  @override
  void dispose() {
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

  Future<void> _onAuthSuccess(AppSettings settings, String message) async {
    final email = _voltis.email;
    if (email != null) {
      await settings.setAccountEmail(email);
    }
    await settings.syncFromVoltis(
      contentCalendarPro: _voltis.contentCalendarPro,
      planTier: _voltis.planTier,
    );
    if (!mounted) return;
    _snack(message);
    if (!widget.embeddedInGate && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitEmail(AppSettings settings) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_voltis.isConfigured) {
      _snack('Voltis Core is not configured on this build.');
      return;
    }
    setState(() => _busy = true);
    final error = await _voltis.signInWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _snack(error);
      return;
    }
    await _onAuthSuccess(
      settings,
      'Welcome back, ${_voltis.email ?? _email.text.trim()}',
    );
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
                      title: const Text('Sign in'),
                    ),
              body: SafeArea(
                child: Form(
                  key: _formKey,
                  child: AuthCenteredBody(
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Logo(theme: theme),
                        const SizedBox(height: 22),
                        Text(
                          'Welcome back',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in with your Voltis Core account. Your calendar stays on this device.',
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
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: (v) => (v ?? '').length < 6
                              ? 'Minimum 6 characters'
                              : null,
                          onFieldSubmitted: (_) {
                            AppHaptics.tap();
                            _submitEmail(settings);
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  AppHaptics.tap();
                                  _submitEmail(settings);
                                },
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
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
                              "Don't have an account? ",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                AppHaptics.tap();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SignUpScreen(
                                      embeddedInGate: widget.embeddedInGate,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Create one'),
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

class _Logo extends StatelessWidget {
  const _Logo({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
