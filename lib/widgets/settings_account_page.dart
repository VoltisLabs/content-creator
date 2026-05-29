import 'package:flutter/material.dart';

import '../screens/auth/sign_in_screen.dart';
import '../models/voltis_plan.dart';
import '../services/subscription_service.dart';
import '../services/voltis_core_service.dart';
import '../state/app_settings.dart';
import '../utils/app_haptics.dart';

/// Settings sub-page: Voltis Core account + plan status (Pinnacle-style).
class SettingsAccountPage extends StatefulWidget {
  const SettingsAccountPage({this.onOpenPlans});

  final VoidCallback? onOpenPlans;

  @override
  State<SettingsAccountPage> createState() => _SettingsAccountPageState();
}

class _SettingsAccountPageState extends State<SettingsAccountPage> {
  bool _busy = false;
  final _voltis = VoltisCoreService.instance;

  Future<void> _refreshEntitlements(AppSettings settings) async {
    if (!_voltis.isSignedIn) return;
    setState(() => _busy = true);
    try {
      await _voltis.refreshEntitlements();
      await applyVoltisSessionToApp(settings);
      _snack('Plan: ${settings.planTier.label}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut(AppSettings settings) async {
    setState(() => _busy = true);
    try {
      await _voltis.signOut();
      await settings.setAccountEmail(null);
      await settings.setContentCalendarPro(false);
      await settings.setPlanTier(VoltisPlanTier.free);
      await SubscriptionService.instance.setCoreProEntitlement(false);
      _snack('Signed out');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEmailSignIn() {
    AppHaptics.tap();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);
    final email = settings.accountEmail;

    return ListenableBuilder(
      listenable: Listenable.merge([settings, SubscriptionService.instance]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ProfileCard(
              email: email,
              planLabel: settings.planTier.label,
            ),
            const SizedBox(height: 18),
            if (email == null) ...[
              Text(
                'SIGN IN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Sign in with email'),
                  subtitle: const Text('Voltis Core account (Supabase)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _openEmailSignIn,
                ),
              ),
            ] else ...[
              Text(
                'SESSION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.verified_user_rounded),
                      title: Text(email),
                      subtitle: Text(
                        '${settings.planTier.label} plan · synced from Voltis Core',
                      ),
                    ),
                    if (widget.onOpenPlans != null) ...[
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.workspace_premium_rounded),
                        title: const Text('Plans'),
                        subtitle: const Text(
                          'View plans and open Voltiscore checkout',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _busy ? null : widget.onOpenPlans,
                      ),
                    ],
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Refresh plan status'),
                      onTap:
                          _busy ? null : () => _refreshEntitlements(settings),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      onTap: _busy ? null : () => _signOut(settings),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Content Calendar never uploads your posts to our servers. Voltis Core only handles sign-in and optional Pro entitlements.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.email, required this.planLabel});

  final String? email;
  final String planLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        (email == null || email!.isEmpty) ? '?' : email![0].toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email ?? 'Guest',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email == null
                        ? 'Sign in to sync Voltis Core entitlements on this device.'
                        : 'Signed in on the $planLabel plan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
