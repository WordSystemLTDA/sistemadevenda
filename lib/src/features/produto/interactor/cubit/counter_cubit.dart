import 'package:app/src/features/produto/interactor/states/counter_state.dart';

import 'package:bloc/bloc.dart';

class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(CounterInitialState(counterValue: 0));

  void increment() => emit(CounterInitialState(counterValue: state.counterValue + 1));
  void decrement() => emit(CounterInitialState(counterValue: state.counterValue - 1));
}
