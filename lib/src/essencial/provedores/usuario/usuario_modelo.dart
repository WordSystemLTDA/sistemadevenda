import 'dart:convert';

import 'package:app/src/essencial/modelos/modelo_configuracoes.dart';

class UsuarioModelo {
  final String? id;
  final String? nivel;
  final String? empresa;
  final String? email;
  final String? senha;
  final String? nome;
  final String? nomeEmpresa;
  final Modelowordconfiguracoes? configuracoes;
  final List<dynamic>? permissoes;

  UsuarioModelo({
    this.id,
    this.nivel,
    this.empresa,
    this.nomeEmpresa,
    this.email,
    this.senha,
    this.nome,
    this.configuracoes,
    this.permissoes,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nivel': nivel,
      'empresa': empresa,
      'nomeEmpresa': nomeEmpresa,
      'email': email,
      'senha': senha,
      'nome': nome,
      'configuracoes': configuracoes?.toMap(),
      'permissoes': permissoes,
    };
  }

  factory UsuarioModelo.fromMap(Map<String, dynamic> map) {
    return UsuarioModelo(
      id: map['id'] != null ? map['id'] as String : null,
      nivel: map['nivel'] != null ? map['nivel'] as String : null,
      empresa: map['empresa'] != null ? map['empresa'] as String : null,
      nomeEmpresa: map['nomeEmpresa'] != null ? map['nomeEmpresa'] as String : null,
      email: map['email'] != null ? map['email'] as String : null,
      senha: map['senha'] != null ? map['senha'] as String : null,
      nome: map['nome'] != null ? map['nome'] as String : null,
      configuracoes: map['configuracoes'] != null ? Modelowordconfiguracoes.fromMap(map['configuracoes'] as Map<String, dynamic>) : null,
      permissoes: map['permissoes'] != null ? List<dynamic>.from((map['permissoes'] as List<dynamic>)) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UsuarioModelo.fromJson(String source) => UsuarioModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
