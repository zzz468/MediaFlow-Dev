class SimulatedDownloadPlan {
  const SimulatedDownloadPlan({
    this.steps = const [0, 0.2, 0.4, 0.6, 0.8, 1],
    this.tickInterval = const Duration(milliseconds: 700),
  });

  final List<double> steps;
  final Duration tickInterval;

  int nextStepIndex(double progress) {
    return steps.indexWhere((step) => step > progress);
  }
}
