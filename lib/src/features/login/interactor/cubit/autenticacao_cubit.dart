import 'package:app/src/features/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/features/login/interactor/states/autenticacao_state.dart';
import 'package:bloc/bloc.dart';

class AutenticacaoCubit extends Cubit<AutenticacaoEstado> {
  final AutenticacaoService _service;

  AutenticacaoCubit(this._service) : super(AutenticacaoEstadoInicial());

  void entrar(usuario, senha) async {
    bool sucesso;

    emit(Carregando());

    await Future.delayed(const Duration(seconds: 1));

    sucesso = await _service.entrar(usuario, senha);

    if (sucesso) {
      emit(Autenticado());
    } else {
      emit(AutenticacaoErro(erro: Exception('Erro ao tentar entrar')));
    }
  }
}
