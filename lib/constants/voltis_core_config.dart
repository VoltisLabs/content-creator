/// Voltis Core API configuration for Content Calendar.
///
/// Desktop builds use the [voltislabs.uk] TLS proxy (`/api/core/*`). Direct
/// `core.voltislabs.uk` currently fails certificate hostname verification.
///
/// Override at build time with `--dart-define`:
///   VOLTIS_CORE_URL=https://voltislabs.uk/api/core
///   VOLTIS_CORE_GRAPHQL_URL=https://voltislabs.uk/api/core/graphql
class VoltisCoreConfig {
  VoltisCoreConfig._();

  static const String _siteOrigin = 'https://voltislabs.uk';

  /// API base (GraphQL + REST entitlements) via the site proxy.
  static const String voltisCoreUrl = String.fromEnvironment(
    'VOLTIS_CORE_URL',
    defaultValue: '$_siteOrigin/api/core',
  );

  static const String graphqlUrl = String.fromEnvironment(
    'VOLTIS_CORE_GRAPHQL_URL',
    defaultValue: '$_siteOrigin/api/core/graphql',
  );

  static const String appId = 'content-calendar';

  /// Checkout / account portal (external browser only).
  static const String billingUrl = String.fromEnvironment(
    'VOLTIS_CORE_BILLING_URL',
    defaultValue: 'https://voltislabs.uk/voltiscore',
  );

  static bool get isConfigured =>
      voltisCoreUrl.isNotEmpty && graphqlUrl.isNotEmpty;
}
