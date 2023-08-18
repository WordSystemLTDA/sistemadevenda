import 'package:app/src/features/produto/interactor/states/counter_state.dart';

import 'package:bloc/bloc.dart';

class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(CounterInitialState(counterValue: 1));

  void increment() {
    emit(CounterInitialState(counterValue: state.counterValue + 1));
  }

  void decrement() {
    if (state.counterValue > 1) {
      emit(CounterInitialState(counterValue: state.counterValue - 1));
    }
  }
}
