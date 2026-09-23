/// Diagnostic-only JSON budgets. No browser lifecycle or network policy here.
class DouyinObservationLimits {
  const DouyinObservationLimits({
    this.maxSingleResponseBytes = 1024 * 1024,
    this.maxJsonDepth = 14,
    this.maxJsonNodes = 12000,
    this.maxStringCharacters = 64 * 1024,
  }) : assert(maxSingleResponseBytes > 0),
       assert(maxJsonDepth >= 0),
       assert(maxJsonNodes > 0),
       assert(maxStringCharacters > 0);

  final int maxSingleResponseBytes;

  /// Root is depth zero; containers and scalar values both count.
  final int maxJsonDepth;

  /// Every JSON value counts, including scalars, arrays and objects.
  final int maxJsonNodes;

  /// Applies to all string values and object keys, not just projected fields.
  final int maxStringCharacters;
}
