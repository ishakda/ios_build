import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/navigation/presentation/cubit/main_navigation_cubit.dart';

void main() {
  test('selectTab updates the selected index', () {
    final cubit = MainNavigationCubit();

    cubit.selectTab(3);

    expect(cubit.state.selectedIndex, 3);
    cubit.close();
  });

  test('clampToTabCount keeps the selected index within range', () {
    final cubit = MainNavigationCubit();
    cubit.selectTab(4);

    cubit.clampToTabCount(3);

    expect(cubit.state.selectedIndex, 2);
    cubit.close();
  });
}
