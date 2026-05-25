import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_version.dart';
import '../constants/legal_urls.dart';
import '../screens/legal_document_screen.dart';
import '../services/app_preferences.dart';
import '../services/custom_background_service.dart';
import '../services/desktop_window.dart' show isDesktop;
import '../services/plan_service.dart';
import '../services/subscription_service.dart';
import '../state/appearance_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_preset.dart';
import '../theme/calendar_ambient_mode.dart';
import '../utils/app_haptics.dart';
import 'calendar_ambient_backdrop.dart';
import 'paywall_sheet.dart';
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
                reverseCurve: Curves.easeInOutCubic,
              ),
            );
            return SlideTransition(position: slide, child: child);
          },
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 250),
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
  });

  final AppearanceController appearance;
  final bool violetDarkMode;
  final bool stayOnTop;
  final ValueChanged<bool> onStayOnTopChanged;
  final VoidCallback onClose;
  final VoidCallback onAppearanceApplied;

  @override
  State<SettingsFlow> createState() => _SettingsFlowState();
}

class _SettingsFlowState extends State<SettingsFlow> {
  final _navKey = GlobalKey<NavigatorState>();

  void _push(String route) => _navKey.currentState!.pushNamed(route);

  AppThemePreset get _previewPreset => widget.appearance.settingsUiPreset;
  bool get _previewUseCustomBg => widget.appearance.settingsUseCustomBackground;

  void _closeSettings() {
    AppHaptics.tap();
    widget.onClose();
  }

  Future<void> _applyPreset(AppThemePreset preset) async {
    AppHaptics.tap();
    await widget.appearance.selectPalettePreset(preset);
    widget.onAppearanceApplied();
  }

  Future<void> _applyAmbient(CalendarAmbientMode mode) async {
    AppHaptics.tap();
    await widget.appearance.selectLiveTheme(mode);
    widget.onAppearanceApplied();
  }

  Future<void> _previewUseCustomBgChanged(bool value) async {
    await widget.appearance.setUseCustomBackground(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCloseScope(
      onClose: _closeSettings,
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
              case '/background':
                page = _SettingsBackgroundPage(
                  useCustomBackground: _previewUseCustomBg,
                  onUseCustomBackgroundChanged: _previewUseCustomBgChanged,
                  onCustomBackgroundChanged: widget.appearance.refreshCustomBackgroundPath,
                  onOpenPaywall: () => _push('/plans'),
                );
              case '/sound':
                page = const _SettingsSoundPage();
              case '/window':
                page = _SettingsWindowPage(
                  stayOnTop: widget.stayOnTop,
                  onStayOnTopChanged: widget.onStayOnTopChanged,
                );
              case '/plans':
                page = const _SettingsPaywallPage();
              case '/about':
                page = const _SettingsAboutPage();
              case '/help':
                page = const _SettingsHelpPage();
              case '/bug':
                page = const _SettingsReportBugPage();
              case '/':
              default:
                page = _SettingsHomePage(
                  onOpenPlans: () => _push('/plans'),
                  onOpenAppearance: () => _push('/appearance'),
                  onOpenBackground: () => _push('/background'),
                  onOpenSound: () => _push('/sound'),
                  onOpenWindow: isDesktop ? () => _push('/window') : null,
                  onOpenAbout: () => _push('/about'),
                  onOpenHelp: () => _push('/help'),
                  onOpenReportBug: () => _push('/bug'),
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
    );
  }
}

class _SettingsPaywallPage extends StatelessWidget {
  const _SettingsPaywallPage();

  @override
  Widget build(BuildContext context) {
    return _SettingsPageShell(
      title: 'Plans & Pro',
      child: const PaywallSheetBody(),
    );
  }
}

class _SettingsPageShell extends StatelessWidget {
  const _SettingsPageShell({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final closeSettings = _SettingsCloseScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close settings',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  AppHaptics.tap();
                  closeSettings();
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
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _SettingsHomePage extends StatefulWidget {
  const _SettingsHomePage({
    required this.onOpenPlans,
    required this.onOpenAppearance,
    required this.onOpenBackground,
    required this.onOpenSound,
    this.onOpenWindow,
    required this.onOpenAbout,
    required this.onOpenHelp,
    required this.onOpenReportBug,
  });

  final VoidCallback onOpenPlans;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenBackground;
  final VoidCallback onOpenSound;
  final VoidCallback? onOpenWindow;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenReportBug;

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
    final isPro = _subscriptions.isPro;

    return _SettingsPageShell(
      title: 'Settings',
      child: Theme(
        data: _settingsListTheme(context),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _navTile(
            icon: isPro ? Icons.workspace_premium_rounded : Icons.star_outline_rounded,
            title: isPro ? 'Pro subscription' : 'Plans & Pro',
            subtitle: isPro ? 'Manage subscription' : 'Upgrade on the App Store',
            onTap: widget.onOpenPlans,
          ),
          const Divider(height: 24),
          _navTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Colour, gradient, and live home themes',
            onTap: widget.onOpenAppearance,
          ),
          const Divider(height: 1),
          _navTile(
            icon: Icons.wallpaper_outlined,
            title: 'Background',
            subtitle: isPro ? 'Custom photo behind calendar' : 'Pro — custom photo',
            onTap: widget.onOpenBackground,
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
            'Choose one look: a colour or gradient palette, or a live animated theme — not both. Tap to apply and return to your calendar.',
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
          _liveThemeGrid(context, liveMode),
        ],
        ),
      ),
    );
  }

  Widget _liveThemeGrid(BuildContext context, CalendarAmbientMode? selected) {
    final desktop = isDesktop || MediaQuery.sizeOf(context).width >= 720;
    final crossAxisCount = desktop ? 4 : 2;
    const tileHeight = 76.0;

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
        final isSelected = selected != null && mode == selected;
        return Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onAmbientSelected(mode),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AmbientThemePreview(mode: mode, time: index * 0.7),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Text(
                    mode.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.check_circle, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsBackgroundPage extends StatefulWidget {
  const _SettingsBackgroundPage({
    required this.useCustomBackground,
    required this.onUseCustomBackgroundChanged,
    required this.onCustomBackgroundChanged,
    required this.onOpenPaywall,
  });

  final bool useCustomBackground;
  final ValueChanged<bool> onUseCustomBackgroundChanged;
  final VoidCallback onCustomBackgroundChanged;
  final VoidCallback onOpenPaywall;

  @override
  State<_SettingsBackgroundPage> createState() => _SettingsBackgroundPageState();
}

class _SettingsBackgroundPageState extends State<_SettingsBackgroundPage> {
  late bool _useCustomBg = widget.useCustomBackground;
  String? _customBgPath;
  var _loading = true;
  final _subscriptions = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptions.addListener(_rebuild);
    _load();
  }

  @override
  void dispose() {
    _subscriptions.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final bg = await CustomBackgroundService.instance.loadBackgroundFile();
    if (!mounted) return;
    setState(() {
      _customBgPath = bg?.path;
      _loading = false;
    });
  }

  bool get _isPro => _subscriptions.isPro;

  void _requirePro() {
    AppHaptics.tap();
    widget.onOpenPaywall();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SettingsPageShell(
        title: 'Background',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _SettingsPageShell(
      title: 'Background',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (!_isPro)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('Pro feature'),
              subtitle: const Text('Upgrade to use your own photo as the backdrop.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _requirePro,
            ),
          if (!_isPro) const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use custom photo'),
            subtitle: const Text('Replaces the live theme with your image.'),
            value: _useCustomBg && _isPro,
            onChanged: _isPro
                ? (value) async {
                    AppHaptics.tap();
                    setState(() => _useCustomBg = value);
                    widget.onUseCustomBackgroundChanged(value);
                  }
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: _isPro,
            leading: _customBgPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_customBgPath!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.image_outlined),
            title: const Text('Choose photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isPro
                ? () async {
                    AppHaptics.tap();
                    await CustomBackgroundService.instance.pickAndSaveBackground();
                    widget.onCustomBackgroundChanged();
                    await _load();
                  }
                : _requirePro,
          ),
          if (_customBgPath != null && _isPro) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remove custom photo'),
              onTap: () async {
                AppHaptics.tap();
                await CustomBackgroundService.instance.clearBackground();
                setState(() => _useCustomBg = false);
                widget.onUseCustomBackgroundChanged(false);
                widget.onCustomBackgroundChanged();
                await _load();
              },
            ),
          ],
        ],
      ),
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

class _SettingsReportBugPage extends StatelessWidget {
  const _SettingsReportBugPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return _SettingsPageShell(
      title: 'Report a bug',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Tell us what went wrong — include your device, app version '
            '(${AppVersion.label}), and steps to reproduce if you can.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              AppHaptics.tap();
              _launchExternalUrl(LegalUrls.reportBug);
            },
            icon: const Icon(Icons.mail_outline),
            label: const Text('Email support'),
          ),
        ],
      ),
    );
  }
}
