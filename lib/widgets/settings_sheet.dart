import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_version.dart';
import '../constants/legal_urls.dart';
import '../models/voltis_plan.dart';
import '../screens/legal_document_screen.dart';
import 'dart:io';

import '../services/app_preferences.dart';
import '../services/bug_report_service.dart';
import '../services/image_pick_service.dart';
import '../services/desktop_window.dart' show isDesktop;
import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../state/app_settings.dart';
import '../state/appearance_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_preset.dart';
import '../theme/calendar_ambient_mode.dart';
import '../utils/app_haptics.dart';
import 'calendar_ambient_backdrop.dart';
import 'settings_account_page.dart';
import 'settings_plans_page.dart';
import 'theme_preset_chip.dart';

Future<void> _launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Horizontal slide between settings sub-pages.
class _SettingsSlideRoute<T> extends PageRouteBuilder<T> {
  _SettingsSlideRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}

ThemeData _settingsListTheme(BuildContext context) {
  final base = Theme.of(context);
  final isDark = base.brightness == Brightness.dark;
  final ink = base.colorScheme.onSurface.withValues(
    alpha: isDark ? 0.05 : 0.07,
  );
  final highlight = base.colorScheme.onSurface.withValues(
    alpha: isDark ? 0.03 : 0.05,
  );
  return base.copyWith(
    splashColor: ink,
    highlightColor: highlight,
    hoverColor: highlight,
    listTileTheme: base.listTileTheme.copyWith(
      selectedTileColor: base.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
    ),
  );
}

class _SettingsCloseScope extends InheritedWidget {
  const _SettingsCloseScope({
    required this.onClose,
    required super.child,
  });

  final VoidCallback onClose;

  static VoidCallback of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SettingsCloseScope>()!
        .onClose;
  }

  @override
  bool updateShouldNotify(_SettingsCloseScope oldWidget) =>
      onClose != oldWidget.onClose;
}

/// Full-screen settings layer; closes via [onClose] (not root navigator pop).
class SettingsFlow extends StatefulWidget {
  const SettingsFlow({
    super.key,
    required this.appearance,
    required this.violetDarkMode,
    required this.stayOnTop,
    required this.onStayOnTopChanged,
    required this.onClose,
    required this.onAppearanceApplied,
    this.onStorageChanged,
  });

  final AppearanceController appearance;
  final bool violetDarkMode;
  final bool stayOnTop;
  final ValueChanged<bool> onStayOnTopChanged;
  final VoidCallback onClose;
  final VoidCallback onAppearanceApplied;
  final VoidCallback? onStorageChanged;

  @override
  State<SettingsFlow> createState() => _SettingsFlowState();
}

class _SettingsFlowState extends State<SettingsFlow> {
  final _navKey = GlobalKey<NavigatorState>();

  void _push(String route) => _navKey.currentState!.pushNamed(route);

  AppThemePreset get _previewPreset => widget.appearance.settingsUiPreset;

  void _closeSettings() {
    AppHaptics.tap();
    widget.onClose();
  }

  Future<void> _applyPreset(AppThemePreset preset) async {
    AppHaptics.tap();
    await widget.appearance.selectPalettePreset(preset);
    if (mounted) setState(() {});
  }

  Future<void> _applyAmbient(CalendarAmbientMode mode) async {
    AppHaptics.tap();
    await widget.appearance.selectLiveTheme(mode);
    if (mounted) setState(() {});
  }

  Future<void> _pushAppearance() async {
    await _navKey.currentState!.pushNamed('/appearance');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCloseScope(
      onClose: _closeSettings,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Theme(
          data: AppTheme.resolve(
            preset: _previewPreset,
            violetDarkMode: widget.violetDarkMode,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Navigator(
                key: _navKey,
          initialRoute: '/',
          onGenerateRoute: (route) {
            Widget page;
            switch (route.name) {
              case '/appearance':
                page = _SettingsAppearancePage(
                  appearance: widget.appearance,
                  onPresetSelected: _applyPreset,
                  onAmbientSelected: _applyAmbient,
                );
              case '/sound':
                page = const _SettingsSoundPage();
              case '/window':
                page = _SettingsWindowPage(
                  stayOnTop: widget.stayOnTop,
                  onStayOnTopChanged: widget.onStayOnTopChanged,
                );
              case '/account':
                page = _SettingsAccountShell(onOpenPlans: () => _push('/plans'));
              case '/plans':
                page = const _SettingsPlansShell();
              case '/about':
                page = const _SettingsAboutPage();
              case '/help':
                page = const _SettingsHelpPage();
              case '/bug':
                page = const _SettingsReportBugPage();
              case '/purge':
                page = _SettingsPurgePage(
                  onPurged: () {
                    widget.onStorageChanged?.call();
                    widget.onClose();
                  },
                );
              case '/':
              default:
                page = _SettingsHomePage(
                  onOpenAccount: () => _push('/account'),
                  onOpenPlans: () => _push('/plans'),
                  onOpenAppearance: _pushAppearance,
                  onOpenSound: () => _push('/sound'),
                  onOpenWindow: isDesktop ? () => _push('/window') : null,
                  onOpenAbout: () => _push('/about'),
                  onOpenHelp: () => _push('/help'),
                  onOpenReportBug: () => _push('/bug'),
                  onOpenPurge: () => _push('/purge'),
                );
            }

            return _SettingsSlideRoute<void>(
              builder: (_) => page,
              settings: route,
            );
          },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsAccountShell extends StatelessWidget {
  const _SettingsAccountShell({required this.onOpenPlans});

  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageShell(
      title: 'Voltis Core Account',
      child: SettingsAccountPage(onOpenPlans: onOpenPlans),
    );
  }
}

class _SettingsPlansShell extends StatelessWidget {
  const _SettingsPlansShell();

  @override
  Widget build(BuildContext context) {
    return _SettingsPageShell(
      title: 'Plans',
      child: const SettingsPlansPage(),
    );
  }
}

class _SettingsPageShell extends StatelessWidget {
  const _SettingsPageShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final closeSettings = _SettingsCloseScope.of(context);
    final settingsNav = Navigator.of(context);
    final canPopSubPage = settingsNav.canPop();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: canPopSubPage ? 'Back' : 'Close settings',
                icon: Icon(
                  canPopSubPage
                      ? Icons.arrow_back_rounded
                      : Icons.close_rounded,
                ),
                onPressed: () {
                  AppHaptics.tap();
                  if (canPopSubPage) {
                    settingsNav.pop();
                  } else {
                    closeSettings();
                  }
                },
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _SettingsPlanBadge extends StatefulWidget {
  const _SettingsPlanBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SettingsPlanBadge> createState() => _SettingsPlanBadgeState();
}

class _SettingsPlanBadgeState extends State<_SettingsPlanBadge> {
  final _subscriptions = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptions.addListener(_rebuild);
  }

  @override
  void dispose() {
    _subscriptions.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);
    final isPro = settings.contentCalendarPro || _subscriptions.isPro;
    final label = isPro ? 'Pro Plan' : 'Free Plan';

    return TextButton(
      onPressed: () {
        AppHaptics.tap();
        widget.onTap();
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: theme.colorScheme.primaryContainer.withValues(
          alpha: isPro ? 0.9 : 0.65,
        ),
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsHomePage extends StatefulWidget {
  const _SettingsHomePage({
    required this.onOpenAccount,
    required this.onOpenPlans,
    required this.onOpenAppearance,
    required this.onOpenSound,
    this.onOpenWindow,
    required this.onOpenAbout,
    required this.onOpenHelp,
    required this.onOpenReportBug,
    required this.onOpenPurge,
  });

  final VoidCallback onOpenAccount;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenSound;
  final VoidCallback? onOpenWindow;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenReportBug;
  final VoidCallback onOpenPurge;

  @override
  State<_SettingsHomePage> createState() => _SettingsHomePageState();
}

class _SettingsHomePageState extends State<_SettingsHomePage> {
  final _subscriptions = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptions.addListener(_rebuild);
  }

  @override
  void dispose() {
    _subscriptions.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _restorePurchases() async {
    AppHaptics.tap();
    if (!_subscriptions.supportsNativeStore) {
      await _subscriptions.openAppStoreListing();
      return;
    }
    await _subscriptions.restorePurchases();
    if (!mounted) return;
    final message = _subscriptions.isPro
        ? 'Pro subscription restored.'
        : (_subscriptions.lastError ??
            'No previous purchase found for this Apple ID.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = AppSettingsScope.of(context);
    final isPro = account.contentCalendarPro || _subscriptions.isPro;

    return _SettingsPageShell(
      title: 'Settings',
      trailing: _SettingsPlanBadge(onTap: widget.onOpenPlans),
      child: Theme(
        data: _settingsListTheme(context),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _navTile(
            icon: Icons.person_outline_rounded,
            title: account.isSignedIn ? 'Voltis Core Account' : 'Sign in',
            subtitle: account.accountEmail ??
                'Voltis Core - sync Pro entitlements on this device',
            onTap: widget.onOpenAccount,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Colour, gradient, and live home themes',
            onTap: widget.onOpenAppearance,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Thumbnail slider feedback',
            onTap: widget.onOpenSound,
          ),
          if (widget.onOpenWindow != null) ...[
            const Divider(height: 1),
            _navTile(
              icon: Icons.desktop_windows_outlined,
              title: 'Window',
              subtitle: 'Stay on top and desktop options',
              onTap: widget.onOpenWindow!,
            ),
          ],
          const Divider(height: 24),
          _navTile(
            icon: isPro ? Icons.workspace_premium_rounded : Icons.star_outline_rounded,
            title: 'Plans',
            subtitle: _plansSubtitle(account),
            onTap: widget.onOpenPlans,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Purge content',
            subtitle: 'Delete posts by day, month, year, or all',
            onTap: widget.onOpenPurge,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.help_outline_rounded,
            title: 'Help and support',
            subtitle: 'Guides and contact Voltis Labs',
            onTap: widget.onOpenHelp,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a bug',
            subtitle: 'Send feedback by email',
            onTap: widget.onOpenReportBug,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.restore_rounded,
            title: 'Restore purchases',
            subtitle: _subscriptions.supportsNativeStore
                ? 'Restore Pro from the App Store'
                : 'Available in the iOS app',
            onTap: _restorePurchases,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version ${AppVersion.label}',
            onTap: widget.onOpenAbout,
          ),
          if (!isPro) ...[
            const Divider(height: 24),
            Text(
              'Free: ${PlanLimits.maxPostsPerDayFree} posts/day, '
              '${PlanLimits.maxPostsPerMonthFree}/month. '
              'This month and next month only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  String _plansSubtitle(AppSettings account) {
    return '${account.planLabel} · Voltiscore';
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        AppHaptics.tap();
        onTap();
      },
    );
  }
}

class _SettingsAppearancePage extends StatelessWidget {
  const _SettingsAppearancePage({
    required this.appearance,
    required this.onPresetSelected,
    required this.onAmbientSelected,
  });

  final AppearanceController appearance;
  final Future<void> Function(AppThemePreset) onPresetSelected;
  final Future<void> Function(CalendarAmbientMode) onAmbientSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        final palettePreset = appearance.settingsPalettePreset;
        final liveMode = appearance.settingsLiveMode;
        final theme = Theme.of(context);

        return _SettingsPageShell(
          title: 'Appearance',
          child: Theme(
            data: _settingsListTheme(context),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Choose one look: a colour or gradient palette, or a live animated theme - not both. Tap to preview, then close settings to apply.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Colour theme',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                HorizontalThemePresetRow(
                  presets: AppThemePreset.classicPresets,
                  selected: palettePreset,
                  onSelected: (preset) => onPresetSelected(preset),
                ),
                const Divider(height: 24),
                Text(
                  'Gradient themes',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                HorizontalThemePresetRow(
                  presets: AppThemePreset.gradientPresets,
                  selected: palettePreset,
                  onSelected: (preset) => onPresetSelected(preset),
                ),
                const Divider(height: 24),
                Text(
                  'Live home theme',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Animated backdrop behind your calendar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                _LiveThemeGrid(
                  selected: liveMode,
                  onSelected: onAmbientSelected,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveThemeGrid extends StatefulWidget {
  const _LiveThemeGrid({
    required this.selected,
    required this.onSelected,
  });

  final CalendarAmbientMode? selected;
  final Future<void> Function(CalendarAmbientMode) onSelected;

  @override
  State<_LiveThemeGrid> createState() => _LiveThemeGridState();
}

class _LiveThemeGridState extends State<_LiveThemeGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _previewTicker;

  @override
  void initState() {
    super.initState();
    _previewTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _previewTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop || MediaQuery.sizeOf(context).width >= 720;
    final crossAxisCount = desktop ? 4 : 2;
    const tileHeight = 76.0;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _previewTicker,
      builder: (context, _) {
        final previewTime = _previewTicker.value * 18;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: tileHeight,
          ),
          itemCount: CalendarAmbientMode.values.length,
          itemBuilder: (context, index) {
            final mode = CalendarAmbientMode.values[index];
            final isSelected =
                widget.selected != null && mode == widget.selected;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onSelected(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: AmbientThemePreview(
                            mode: mode,
                            time: previewTime + mode.index * 0.65,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Text(
                          mode.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Selected',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsSoundPage extends StatefulWidget {
  const _SettingsSoundPage();

  @override
  State<_SettingsSoundPage> createState() => _SettingsSoundPageState();
}

class _SettingsSoundPageState extends State<_SettingsSoundPage> {
  late bool _sliderSilent;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final silent = await AppPreferences.isSliderSilent();
    if (!mounted) return;
    setState(() {
      _sliderSilent = silent;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SettingsPageShell(
        title: 'Sound',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _SettingsPageShell(
      title: 'Sound',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Silent slider mode'),
            subtitle: const Text(
              'Mute the click sound when adjusting thumbnail size on mobile.',
            ),
            value: _sliderSilent,
            onChanged: (value) async {
              AppHaptics.tap();
              setState(() => _sliderSilent = value);
              await AppPreferences.setSliderSilent(value);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsWindowPage extends StatefulWidget {
  const _SettingsWindowPage({
    required this.stayOnTop,
    required this.onStayOnTopChanged,
  });

  final bool stayOnTop;
  final ValueChanged<bool> onStayOnTopChanged;

  @override
  State<_SettingsWindowPage> createState() => _SettingsWindowPageState();
}

class _SettingsWindowPageState extends State<_SettingsWindowPage> {
  late bool _stayOnTop = widget.stayOnTop;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageShell(
      title: 'Window',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Stay on top'),
            subtitle: const Text('Keep the window above other apps'),
            value: _stayOnTop,
            onChanged: (value) async {
              AppHaptics.tap();
              setState(() => _stayOnTop = value);
              widget.onStayOnTopChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsAboutPage extends StatelessWidget {
  const _SettingsAboutPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return _SettingsPageShell(
      title: 'About',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Content Calendar',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppVersion.label}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Text(
            'Plan and organise social content on a visual calendar. '
            'Created by Voltis Labs.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Voltis Labs website'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              AppHaptics.tap();
              _launchExternalUrl(LegalUrls.website);
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terms of use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppHaptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LegalDocumentScreen(
                    title: 'Terms of use',
                    url: LegalUrls.termsOfUse,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppHaptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LegalDocumentScreen(
                    title: 'Privacy policy',
                    url: LegalUrls.privacyPolicy,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsHelpPage extends StatelessWidget {
  const _SettingsHelpPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return _SettingsPageShell(
      title: 'Help and support',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Guides, FAQs, and contact options for Content Calendar are on the Voltis Labs support site.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              AppHaptics.tap();
              _launchExternalUrl(LegalUrls.helpAndSupport);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open support site'),
          ),
        ],
      ),
    );
  }
}

class _SettingsReportBugPage extends StatefulWidget {
  const _SettingsReportBugPage();

  @override
  State<_SettingsReportBugPage> createState() => _SettingsReportBugPageState();
}

class _SettingsReportBugPageState extends State<_SettingsReportBugPage> {
  final _summary = TextEditingController();
  final _description = TextEditingController();
  final _attachments = <BugReportAttachment>[];
  bool _submitting = false;

  @override
  void dispose() {
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_attachments.length >= BugReportService.maxAttachments) {
      _snack('You can attach up to ${BugReportService.maxAttachments} images.');
      return;
    }
    AppHaptics.tap();
    final files = await ImagePickService.pickMultipleImages();
    if (!mounted || files.isEmpty) return;

    for (final file in files) {
      if (_attachments.length >= BugReportService.maxAttachments) break;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.length > BugReportService.maxBytesPerImage) {
          _snack('${file.path.split('/').last} is too large (max 4 MB).');
          continue;
        }
        final name = file.path.split(Platform.pathSeparator).last;
        final mime = _mimeForPath(name);
        setState(() {
          _attachments.add(
            BugReportAttachment(name: name, mime: mime, bytes: bytes),
          );
        });
      } on Object {
        _snack('Could not read one of the images.');
      }
    }
  }

  String _mimeForPath(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final settings = AppSettingsScope.read(context);
    final email = settings.accountEmail;
    if (email == null || email.isEmpty) {
      _snack('Sign in under Voltis Core Account first.');
      return;
    }

    setState(() => _submitting = true);
    AppHaptics.tap();
    try {
      final message = await BugReportService.submit(
        email: email,
        summary: _summary.text,
        description: _description.text,
        attachments: List.unmodifiable(_attachments),
      );
      if (!mounted) return;
      _snack(message);
      Navigator.of(context).pop();
    } on BugReportException catch (error) {
      _snack(error.message);
    } catch (_) {
      _snack('Could not send report. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final settings = AppSettingsScope.of(context);

    return _SettingsPageShell(
      title: 'Report a bug',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Describe what went wrong. Your report goes straight to the '
            'Voltiscore ADL dashboard — device and app version '
            '(${AppVersion.label}) are included automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (settings.accountEmail == null) ...[
            const SizedBox(height: 12),
            Text(
              'Sign in under Voltis Core Account so we can reply to you.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _summary,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Short summary',
              hintText: 'e.g. Plans page shows Free after purchase',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              hintText: 'Steps to reproduce, what you expected, what you saw…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Screenshots (optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _attachments.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _attachments[i].bytes,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          AppHaptics.tap();
                          setState(() => _attachments.removeAt(i));
                        },
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
              if (_attachments.length < BugReportService.maxAttachments)
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add images'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting || settings.accountEmail == null
                ? null
                : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_submitting ? 'Sending…' : 'Send to Voltiscore'),
          ),
        ],
      ),
    );
  }
}

class _SettingsPurgePage extends StatefulWidget {
  const _SettingsPurgePage({required this.onPurged});

  final VoidCallback onPurged;

  @override
  State<_SettingsPurgePage> createState() => _SettingsPurgePageState();
}

class _SettingsPurgePageState extends State<_SettingsPurgePage> {
  final _storage = StorageService.instance;
  PurgeScope _scope = PurgeScope.day;
  DateTime _target = DateTime.now();

  DateTime? get _targetForScope =>
      _scope == PurgeScope.all ? null : _target;

  int get _postCount =>
      _storage.countPostsForPurge(scope: _scope, target: _targetForScope);

  Future<void> _pickTarget() async {
    AppHaptics.tap();
    switch (_scope) {
      case PurgeScope.day:
        final picked = await showDatePicker(
          context: context,
          initialDate: _target,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _target = picked);
      case PurgeScope.month:
        final picked = await showDatePicker(
          context: context,
          initialDate: _target,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: 'Select a day in the month to purge',
        );
        if (picked != null) {
          setState(() => _target = DateTime(picked.year, picked.month));
        }
      case PurgeScope.year:
        final year = await showDialog<int>(
          context: context,
          builder: (context) {
            final controller = TextEditingController(text: '${_target.year}');
            return AlertDialog(
              title: const Text('Year to purge'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 2026'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, int.tryParse(controller.text.trim()));
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        if (year != null && year >= 2000 && year <= 2100) {
          setState(() => _target = DateTime(year));
        }
      case PurgeScope.all:
        break;
    }
  }

  String get _targetLabel {
    switch (_scope) {
      case PurgeScope.day:
        return DateFormat('EEEE, MMMM d, yyyy').format(_target);
      case PurgeScope.month:
        return DateFormat('MMMM yyyy').format(_target);
      case PurgeScope.year:
        return '${_target.year}';
      case PurgeScope.all:
        return 'Entire app';
    }
  }

  Future<void> _confirmPurge() async {
    if (_scope != PurgeScope.all && _postCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to delete for this selection.')),
      );
      return;
    }

    final scopeLabel = switch (_scope) {
      PurgeScope.day => 'this day',
      PurgeScope.month => 'this month',
      PurgeScope.year => 'this year',
      PurgeScope.all => 'all content in the app',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete content?'),
        content: Text(
          _scope == PurgeScope.all
              ? 'This permanently deletes every post and image. This cannot be undone.'
              : 'Delete $_postCount post${_postCount == 1 ? '' : 's'} for $scopeLabel ($_targetLabel)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleted = await _storage.purgeContent(
      scope: _scope,
      target: _targetForScope,
    );
    if (!mounted) return;

    widget.onPurged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == 0
              ? 'No posts were deleted.'
              : 'Deleted $deleted post${deleted == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAll = _storage.countPostsForPurge(scope: PurgeScope.all);

    return _SettingsPageShell(
      title: 'Purge content',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Permanently remove posts and images. Choose what to delete.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          ...PurgeScope.values.map((scope) {
            final label = switch (scope) {
              PurgeScope.day => 'One day',
              PurgeScope.month => 'One month',
              PurgeScope.year => 'One year',
              PurgeScope.all => 'Everything',
            };
            return RadioListTile<PurgeScope>(
              value: scope,
              groupValue: _scope,
              onChanged: (value) {
                if (value == null) return;
                AppHaptics.tap();
                setState(() => _scope = value);
              },
              title: Text(label),
              contentPadding: EdgeInsets.zero,
            );
          }),
          if (_scope != PurgeScope.all) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target'),
              subtitle: Text(_targetLabel),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickTarget,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _scope == PurgeScope.all
                ? '$totalAll post${totalAll == 1 ? '' : 's'} will be deleted'
                : '$_postCount post${_postCount == 1 ? '' : 's'} will be deleted',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmPurge,
            child: const Text('Purge selected content'),
          ),
        ],
      ),
    );
  }
}
