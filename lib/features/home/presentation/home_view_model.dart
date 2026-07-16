import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeViewState>(
  HomeViewModel.new,
);

class HomeViewModel extends Notifier<HomeViewState> {
  @override
  HomeViewState build() => const HomeViewState();

  void updateLink(String value) {
    state = HomeViewState(link: value);
  }

  void clear() {
    state = const HomeViewState();
  }
}

class HomeViewState {
  const HomeViewState({this.link = ''});

  final String link;

  bool get canProcess => link.trim().isNotEmpty;
}
