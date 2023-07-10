sealed class CounterState {
  final int counterValue;
  CounterState({required this.counterValue});
}

class CounterInitialState extends CounterState {
  CounterInitialState({required int counterValue}) : super(counterValue: counterValue);
}
