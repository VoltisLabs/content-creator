import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/legal_urls.dart';
import '../services/plan_service.dart';
import '../services/subscription_service.dart';
import '../screens/legal_document_screen.dart';
import '../utils/app_haptics.dart';
import 'haptic_buttons.dart';

/// Full-screen Pro paywall. Returns `true` if the user upgraded during this flow.
Future<bool> showPaywallSheet(
  BuildContext context, {
  String? feature,
}) {
  return showPaywallScreen(context, feature: feature);
}

Future<bool> showPaywallScreen(
  BuildContext context, {
  String? feature,
}) async {
  final upgraded = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PaywallScreen(feature: feature),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
  return upgraded ?? false;
}

class _PaywallScreen extends StatelessWidget {
  const _PaywallScreen({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () {
                      AppHaptics.tap();
                      Navigator.of(context).pop(false);
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Plans',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: PaywallSheetBody(feature: feature)),
          ],
        ),
      ),
    );
  }
}

class PaywallSheetBody extends StatefulWidget {
  const PaywallSheetBody({
    super.key,
    this.feature,
    this.embeddedInSettings = false,
  });

  final String? feature;

  /// When shown inside settings, do not auto-pop the nested navigator on Pro.
  final bool embeddedInSettings;

  @override
  State<PaywallSheetBody> createState() => _PaywallSheetBodyState();
}

class _PaywallSheetBodyState extends State<PaywallSheetBody> {
  final _subscriptions = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptions.addListener(_onSubscriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_subscriptions.refreshStoreCatalog());
    });
  }

  @override
  void dispose() {
    _subscriptions.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    if (_subscriptions.isPro && !widget.embeddedInSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
      return;
    }
    setState(() {});
  }

  Future<void> _purchase() async {
    AppHaptics.tap();
    await _subscriptions.purchasePro();
  }

  Future<void> _restore() async {
    AppHaptics.tap();
    await _subscriptions.restorePurchases();
  }

  Future<void> _retryStore() async {
    AppHaptics.tap();
    await _subscriptions.refreshStoreCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = _subscriptions.isPro;
    final plan = isPro ? SubscriptionPlan.pro : SubscriptionPlan.free;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Upgrade to Pro',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.feature != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.feature!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _ProBenefitsList(),
          const SizedBox(height: 16),
          PlanCard(
            plan: plan,
            subscribeButtonLabel: _subscriptions.subscribeButtonLabel,
            purchasePending: _subscriptions.purchasePending,
            supportsNativeStore: _subscriptions.supportsNativeStore,
            onUpgrade: _purchase,
            onRestore: _subscriptions.supportsNativeStore ? _restore : null,
            onManageSubscription: isPro && _subscriptions.supportsNativeStore
                ? _subscriptions.openManageSubscriptions
                : null,
          ),
          if (_subscriptions.lastError != null &&
              _subscriptions.proProduct == null) ...[
            const SizedBox(height: 12),
            Text(
              _subscriptions.lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            if (_subscriptions.supportsNativeStore) ...[
              const SizedBox(height: 8),
              Center(
                child: HapticTextButton(
                  onPressed: _retryStore,
                  child: const Text('Retry App Store connection'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          _LegalLinks(),
          const SizedBox(height: 12),
          Text(
            _subscriptions.supportsNativeStore
                ? 'Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current billing period.'
                : 'Pro subscriptions are available through the Content Calendar iOS app on the App Store.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBenefitsList extends StatelessWidget {
  const _ProBenefitsList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
      height: 1.45,
    );

    const benefits = [
      'Unlimited posts every day and month',
      'Plan content in any future month',
      'Share whole months with another device on your Wi‑Fi',
      'Custom photo backgrounds',
      'All gradient and live home themes',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pro includes',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...benefits.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: style)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onUpgrade,
    required this.subscribeButtonLabel,
    this.purchasePending = false,
    this.supportsNativeStore = true,
    this.onRestore,
    this.onManageSubscription,
  });

  final SubscriptionPlan plan;
  final VoidCallback onUpgrade;
  final String subscribeButtonLabel;
  final bool purchasePending;
  final bool supportsNativeStore;
  final VoidCallback? onRestore;
  final VoidCallback? onManageSubscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = plan == SubscriptionPlan.pro;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro ? Icons.workspace_premium_rounded : Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isPro ? 'Pro' : 'Free',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPro
                ? 'Unlimited posts, any-month planning, month sharing, and custom backgrounds.'
                : 'Up to ${PlanLimits.maxPostsPerDayFree} posts/day and '
                    '${PlanLimits.maxPostsPerMonthFree}/month in this month and next month.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          if (isPro && onManageSubscription != null)
            OutlinedButton(
              onPressed: AppHaptics.wrap(onManageSubscription),
              child: const Text('Manage subscription'),
            )
          else if (!isPro)
            HapticFilledButton(
              onPressed: purchasePending ? null : onUpgrade,
              child: purchasePending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      supportsNativeStore
                          ? subscribeButtonLabel
                          : 'Get Pro on iOS',
                    ),
            ),
          if (!isPro && onRestore != null) ...[
            const SizedBox(height: 8),
            Center(
              child: HapticTextButton(
                onPressed: purchasePending ? null : onRestore,
                child: const Text('Restore purchases'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        HapticTextButton(
          onPressed: () => _openLegal(context, 'Terms of use', LegalUrls.termsOfUse),
          child: Text('Terms of use', style: style),
        ),
        Text(' · ', style: style),
        HapticTextButton(
          onPressed: () =>
              _openLegal(context, 'Privacy Policy', LegalUrls.privacyPolicy),
          child: Text('Privacy Policy', style: style),
        ),
      ],
    );
  }

  void _openLegal(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, url: url),
      ),
    );
  }
}
