/// As novas integracoes com o painel nao alteram instalacoes Local/REDE.
class PoliticaOfflineOnline {
  static const tipoInstalador =
      String.fromEnvironment('TIPO_INSTALADOR', defaultValue: '2');
  static const conexao =
      String.fromEnvironment('CONEXAO', defaultValue: 'online');

  static bool permite(String? conexaoAtual,
          {String instalador = tipoInstalador, String ambiente = conexao}) =>
      instalador == '2' && ambiente == 'online' && conexaoAtual == 'online';
}
