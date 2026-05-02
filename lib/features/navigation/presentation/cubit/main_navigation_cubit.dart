import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MainNavigationState extends Equatable {
  const MainNavigationState({this.selectedIndex = 0});

  final int selectedIndex;

  MainNavigationState copyWith({int? selectedIndex}) {
    return MainNavigationState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }

  @override
  List<Object> get props => [selectedIndex];
}

class MainNavigationCubit extends Cubit<MainNavigationState> {
  MainNavigationCubit() : super(const MainNavigationState());

  void selectTab(int index) {
    if (index < 0 || index == state.selectedIndex) {
      return;
    }
    emit(state.copyWith(selectedIndex: index));
  }

  void clampToTabCount(int tabCount) {
    if (tabCount <= 0) {
      return;
    }

    final lastValidIndex = tabCount - 1;
    if (state.selectedIndex > lastValidIndex) {
      emit(state.copyWith(selectedIndex: lastValidIndex));
    }
  }
}
