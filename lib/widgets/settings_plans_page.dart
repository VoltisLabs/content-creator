import 'package:flutter/material.dart';

import '../models/voltis_plan.dart';
import '../services/subscription_service.dart';
import '../services/voltis_billing.dart';
import '../services/voltis_core_service.dart';
import '../services/voltis_plans_service.dart';
import '../state/app_settings.dart';
import '../utils/app_haptics.dart';

/// Plans catalog inside settings (Pinnacle-style, Voltiscore checkout).
class SettingsPlansPage extends StatefulWidget {
  const SettingsPlansPage({super.key});

  @override
  State<SettingsPlansPage> createState() => _SettingsPlansPageState();
}

class _SettingsPlansPageState extends State<SettingsPlansPage> {
  VoltisPlansCatalog? _catalog;
  String? _loadError;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog({bool refreshEntitlements = false}) async {
    final settings = AppSettingsScope.read(context);
    setState(() {
      _loading = _catalog == null;
      _refreshing = _catalog != null;
      _loadError = null;
    });

    if (refreshEntitlements) {
      final voltis = VoltisCoreService.instance;
      if (voltis.isSignedIn) {
        await voltis.refreshEntitlements();
        await applyVoltisSessionToApp(settings);
      }
    }

    try {
      final catalog = await VoltisPlansService.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadError = null;
      });
    } on VoltisPlansException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError = 'Could not load plans. Check your connection.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final currentTier = settings.planTier;
    final storePro = SubscriptionService.instance.isPro &&
        !settings.contentCalendarPro;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_loadError != null) {
      return _PlansErrorState(
        message: _loadError!,
        onRetry: () => _loadCatalog(refreshEntitlements: true),
      );
    }

    final catalog = _catalog!;

    return RefreshIndicator(
      onRefresh: () => _loadCatalog(refreshEntitlements: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _SubscriptionHeader(
            currentTier: currentTier,
            email: settings.accountEmail,
            appName: catalog.appName,
            storeProActive: storePro,
          ),
          const SizedBox(height: 16),
          const _ExternalBillingNotice(),
          const SizedBox(height: 20),
          Text(
            'Available plans',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Three ways to get Pro: 3 months (£11.99), 6 months (£29.99), or '
            'Forever (£79.99) on Voltiscore. Tap a paid plan to open checkout '
            'in your browser - desktop does not process payments.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          for (final plan in catalog.plans)
            _PlanCard(
              plan: plan,
              isCurrent: currentTier == plan.tier,
              onSelect: plan.isFree || currentTier == plan.tier
                  ? null
                  : () {
                      AppHaptics.tap();
                      VoltisBilling.openCheckout(context, tier: plan.tier);
                    },
            ),
          const SizedBox(height: 8),
          if (_refreshing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(height: 8),
          const _StoreBillingNote(),
        ],
      ),
    );
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({
    required this.currentTier,
    required this.appName,
    this.email,
    this.storeProActive = false,
  });

  final VoltisPlanTier currentTier;
  final String appName;
  final String? email;
  final bool storeProActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current plan',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            storeProActive ? 'Pro (App Store)' : currentTier.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (email != null) ...[
            const SizedBox(height: 8),
            Text(
              email!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onSelect,
  });

  final VoltisPlanOffer plan;
  final bool isCurrent;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final featured = plan.recommended && !isCurrent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? scheme.primary
              : featured
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.45),
          width: isCurrent || featured ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.badge != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            plan.badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        plan.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.isFree ? 'Free' : plan.priceDisplay,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          if (!plan.isFree && plan.billingLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                plan.billingLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                plan.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final feature in plan.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (!plan.isFree) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    isCurrent ? 'Current plan' : 'View on Voltiscore',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExternalBillingNotice extends StatelessWidget {
  const _ExternalBillingNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.language_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payments on Voltiscore only',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Paid plans are purchased on the Voltis Core portal at '
            'voltislabs.uk/voltiscore - not in this desktop app. After checkout, '
            'return here and pull to refresh (or use Refresh plan status in '
            'Voltis Core Account).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreBillingNote extends StatelessWidget {
  const _StoreBillingNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'On iOS you can also subscribe through the App Store. Desktop and Android '
      'use Voltiscore for paid plans.',
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );
  }
}

class _PlansErrorState extends StatelessWidget {
  const _PlansErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                AppHaptics.tap();
                onRetry();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
