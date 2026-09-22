import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';

class MontagemCardapio {
  static ModeloDadosOpcoesPacotes aplicar(
    ModeloDadosOpcoesPacotes ingrediente,
    MontagemIngredienteCardapio montagem,
  ) {
    final valorEmbalagem = double.tryParse(
          montagem.valorEmbalagemSeparada.replaceAll(',', '.'),
        ) ??
        0;
    final cobrarEmbalagem = montagem.separado &&
        montagem.acao != AcaoIngredienteCardapio.sem &&
        valorEmbalagem > 0;
    return ModeloDadosOpcoesPacotes.fromMap({
      ...ingrediente.toMap(),
      'nome': montagem.descricao,
      'montagemCardapio': montagem.toMap(),
      'estaSelecionado': true,
      'quantidade': 1,
      'valor': cobrarEmbalagem ? montagem.valorEmbalagemSeparada : '0',
    });
  }

  static List<ModeloDadosOpcoesPacotes> iniciar(
    List<ModeloDadosOpcoesPacotes> disponiveis, {
    List<ModeloDadosOpcoesPacotes>? salvos,
    bool novosComoNormal = false,
  }) {
    final salvosPorId = {
      for (final item in salvos ?? <ModeloDadosOpcoesPacotes>[]) item.id: item,
    };
    final possuiSalvos = salvosPorId.isNotEmpty;

    return [
      for (final ingrediente in disponiveis)
        if (salvosPorId[ingrediente.id]?.montagemCardapio != null)
          _restaurarSalvo(
            ingrediente,
            salvosPorId[ingrediente.id]!,
          )
        else
          aplicar(
            ingrediente,
            MontagemIngredienteCardapio(
              nomeOriginal: ingrediente.montagemCardapio?.nomeOriginal ??
                  ingrediente.nome,
              acao: acaoInicial(
                ingrediente,
                preferirSem: possuiSalvos && !novosComoNormal,
              ),
            ),
          ),
    ];
  }

  static ModeloDadosOpcoesPacotes _restaurarSalvo(
    ModeloDadosOpcoesPacotes disponivel,
    ModeloDadosOpcoesPacotes salvo,
  ) {
    final permissoes = disponivel.permissoesMontagemCardapio.isNotEmpty
        ? disponivel.permissoesMontagemCardapio
        : salvo.permissoesMontagemCardapio;
    final atualizado = ModeloDadosOpcoesPacotes.fromMap({
      ...salvo.toMap(),
      if (permissoes.isNotEmpty) 'permissoesMontagemCardapio': permissoes,
    });
    final montagem = atualizado.montagemCardapio;
    if (montagem == null || atualizado.permiteMontagemCardapio(montagem.acao)) {
      return atualizado;
    }
    return aplicar(
      atualizado,
      montagem.copyWith(acao: acaoInicial(atualizado)),
    );
  }

  static AcaoIngredienteCardapio acaoInicial(
    ModeloDadosOpcoesPacotes item, {
    bool preferirSem = false,
  }) {
    final preferencia = preferirSem
        ? AcaoIngredienteCardapio.sem
        : AcaoIngredienteCardapio.normal;
    if (item.permiteMontagemCardapio(preferencia)) return preferencia;

    for (final acao in const [
      AcaoIngredienteCardapio.normal,
      AcaoIngredienteCardapio.pouco,
      AcaoIngredienteCardapio.mais,
      AcaoIngredienteCardapio.sem,
    ]) {
      if (item.permiteMontagemCardapio(acao)) return acao;
    }
    return AcaoIngredienteCardapio.normal;
  }

  static String? validarTroca(
    List<ModeloDadosOpcoesPacotes> montagem,
    String origemId,
    String destinoId,
    String destinoTipo,
  ) {
    if (destinoTipo != 'ingrediente') return null;
    if (origemId == destinoId) {
      return 'Escolha um ingrediente diferente para trocar.';
    }
    final destino = montagem.where((item) => item.id == destinoId).firstOrNull;
    if (destino == null) return 'Ingrediente indisponível para troca.';
    final acaoDestino =
        destino.montagemCardapio?.acao ?? AcaoIngredienteCardapio.normal;
    if (acaoDestino == AcaoIngredienteCardapio.sem ||
        acaoDestino == AcaoIngredienteCardapio.trocar) {
      return 'Este ingrediente não pode receber troca agora.';
    }
    if (recebeTroca(montagem, origemId)) {
      return 'Este ingrediente já recebe uma troca.';
    }
    return null;
  }

  static bool recebeTroca(
    List<ModeloDadosOpcoesPacotes> montagem,
    String ingredienteId,
  ) {
    return montagem.any((item) =>
        item.id != ingredienteId &&
        item.montagemCardapio?.acao == AcaoIngredienteCardapio.trocar &&
        item.montagemCardapio?.destinoId == ingredienteId &&
        item.montagemCardapio?.destinoTipo == 'ingrediente');
  }
}
