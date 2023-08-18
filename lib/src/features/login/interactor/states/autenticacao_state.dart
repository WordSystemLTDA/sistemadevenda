sealed class AutenticacaoEstado {}

class AutenticacaoEstadoInicial extends AutenticacaoEstado {}

class Carregando extends AutenticacaoEstado {}

class Autenticado extends AutenticacaoEstado {}

class AutenticacaoErro extends AutenticacaoEstado {
  final Exception erro;
  AutenticacaoErro({required this.erro}) : super();
}
