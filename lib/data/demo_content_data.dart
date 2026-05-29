import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../models/content_image.dart';

/// Bundled demo calendar content (7 themed days in the current month).
class DemoContentData {
  DemoContentData._();

  static const _folders = [
    _DemoDaySpec(
      folder: 'footy',
      caption:
          'Match-day energy - quick recap of the weekend fixtures and crowd moments.',
      tags: ['footy', 'weekend', 'sports'],
      altIndexes: {0},
    ),
    _DemoDaySpec(
      folder: 'jessie',
      caption:
          'Golden-hour street style - four looks to rotate through the week.',
      tags: ['style', 'ootd', 'golden-hour'],
      altIndexes: {0, 2},
    ),
    _DemoDaySpec(
      folder: 'memes',
      caption: 'Relatable creator memes for a light mid-week post.',
      tags: ['meme', 'humour', 'relatable'],
      altIndexes: {1},
    ),
    _DemoDaySpec(
      folder: 'mens',
      caption: 'Menswear drop preview - tailored layers and neutral palette.',
      tags: ['menswear', 'fashion', 'drop'],
      altIndexes: {0, 1},
    ),
    _DemoDaySpec(
      folder: 'mira',
      caption: 'Portrait set for the brand story carousel.',
      tags: ['portrait', 'brand', 'carousel'],
      altIndexes: {0},
    ),
    _DemoDaySpec(
      folder: 'mockups',
      caption: 'Product mockups for the spring campaign landing page.',
      tags: ['mockup', 'campaign', 'product'],
      altIndexes: {0, 3, 5},
    ),
    _DemoDaySpec(
      folder: 'theresa',
      caption: 'Casual day-in-the-life - coffee run, errands, and outfit details.',
      tags: ['casual', 'lifestyle', 'day-in-life'],
      altIndexes: {1},
    ),
  ];

  static DateTime get currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  static Map<String, List<ContentEntry>> entriesForMonth(DateTime month) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final dayNumbers = <int>[
      for (var i = 0; i < _folders.length; i++)
        1 + ((daysInMonth - 1) * i / (_folders.length - 1)).round(),
    ];

    final entries = <String, List<ContentEntry>>{};
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _folders.length; i++) {
      final spec = _folders[i];
      final day = dayNumbers[i].clamp(1, daysInMonth);
      final date = DateTime(month.year, month.month, day);
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final assetPaths = _assetPathsForFolder(spec.folder);

      final images = <ContentImage>[
        for (var j = 0; j < assetPaths.length; j++)
          ContentImage(
            id: 'demo-$dateKey-$j',
            path: assetPaths[j],
            altDescription: spec.altIndexes.contains(j)
                ? _altFor(spec.folder, j)
                : '',
          ),
      ];

      entries[dateKey] = [
        ContentEntry(
          id: 'demo-$dateKey',
          dateKey: dateKey,
          createdAtMillis: nowMs - (i * 7200000),
          caption: spec.caption,
          tags: spec.tags,
          coverImagePath: images.first.path,
          images: images,
        ),
      ];
    }

    return entries;
  }

  static List<String> _assetPathsForFolder(String folder) {
    const files = {
      'footy': [
        'assets/demo_content/footy/IMG_3666.JPG',
        'assets/demo_content/footy/IMG_5066.PNG',
        'assets/demo_content/footy/IMG_5087_1.PNG',
      ],
      'jessie': [
        'assets/demo_content/jessie/IMG_8400.jpg',
        'assets/demo_content/jessie/IMG_8401.jpg',
        'assets/demo_content/jessie/IMG_8402.jpg',
        'assets/demo_content/jessie/IMG_8403.jpg',
      ],
      'memes': [
        'assets/demo_content/memes/IMG_8879.GIF',
        'assets/demo_content/memes/IMG_8991.PNG',
      ],
      'mens': [
        'assets/demo_content/mens/IMG_9024.PNG',
        'assets/demo_content/mens/IMG_9025.PNG',
        'assets/demo_content/mens/IMG_9026.PNG',
        'assets/demo_content/mens/IMG_9027.PNG',
      ],
      'mira': [
        'assets/demo_content/mira/IMG_8993.PNG',
        'assets/demo_content/mira/IMG_8994.PNG',
      ],
      'mockups': [
        'assets/demo_content/mockups/IMG_8810.PNG',
        'assets/demo_content/mockups/IMG_8811.PNG',
        'assets/demo_content/mockups/IMG_8812.PNG',
        'assets/demo_content/mockups/IMG_8813.PNG',
        'assets/demo_content/mockups/IMG_8814.PNG',
        'assets/demo_content/mockups/IMG_8815.PNG',
        'assets/demo_content/mockups/IMG_8816.PNG',
      ],
      'theresa': [
        'assets/demo_content/theresa/4C15FA1E-F2E5-4D92-9CB4-4D47540C8481.JPG',
        'assets/demo_content/theresa/6B6E0CE0-1700-40D7-8AA2-3A4ABFA3FF6B.JPG',
        'assets/demo_content/theresa/C731B5F4-40A6-4B26-86D7-095DC19CE27A.JPG',
      ],
    };
    return files[folder] ?? const [];
  }

  static String _altFor(String folder, int index) {
    return switch (folder) {
      'footy' => 'Fans cheering under stadium lights after the final whistle.',
      'jessie' => index == 0
          ? 'Full-length outfit shot on a city sidewalk at sunset.'
          : 'Close-up of layered jewellery and textured jacket.',
      'memes' => 'Meme image with bold caption about creator burnout.',
      'mens' => index == 0
          ? 'Model wearing charcoal overcoat and white trainers.'
          : 'Flat-lay of menswear accessories on a wooden table.',
      'mira' => 'Soft-lit portrait with neutral background.',
      'mockups' => 'Phone mockup showing app screen on a desk setup.',
      'theresa' => 'Casual mirror selfie in a bright café corner.',
      _ => 'Demo content image.',
    };
  }
}

class _DemoDaySpec {
  const _DemoDaySpec({
    required this.folder,
    required this.caption,
    required this.tags,
    required this.altIndexes,
  });

  final String folder;
  final String caption;
  final List<String> tags;
  final Set<int> altIndexes;
}
