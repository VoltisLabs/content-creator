class TransferProgress {
  const TransferProgress({
    required this.fraction,
    required this.label,
  });

  final double fraction;
  final String label;

  int get percent => (fraction.clamp(0, 1) * 100).round();
}

typedef TransferProgressCallback = void Function(TransferProgress progress);
