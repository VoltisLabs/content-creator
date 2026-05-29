import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/voltis_core_config.dart';
import '../models/voltis_plan.dart';

/// External checkout on Voltiscore — no in-app purchases on desktop.
abstract final class VoltisBilling {
  static Uri checkoutUri(VoltisPlanTier tier) {
    return Uri.parse(VoltisCoreConfig.billingUrl).replace(
      queryParameters: {
        'app': VoltisCoreConfig.appId,
        'plan': tier.checkoutId,
      },
    );
  }

  static Future<void> openCheckout(
    BuildContext context, {
    required VoltisPlanTier tier,
  }) async {
    final uri = checkoutUri(tier);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!context.mounted) return;

    if (!launched) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Voltiscore portal'),
          content: Text(
            'Paid plans are purchased on the Voltis Core website (${uri.host}), '
            'not in this app. Open that site in your browser to complete checkout, '
            'then return here and refresh your subscription.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
