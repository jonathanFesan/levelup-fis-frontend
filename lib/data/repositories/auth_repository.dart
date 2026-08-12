// Arquivo: frontend/lib/data/repositories/auth_repository.dart
// Chamadas HTTP para autenticação

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:levelup_fis/core/constants/app_constants.dart';

class AuthRepository {
  final String baseUrl = AppConstants.baseUrl;

  /// Realiza o cadastro de um novo usuário
  Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Erro ao cadastrar usuário.');
    }
  }

  /// Realiza o login com email e senha
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Email ou senha incorretos.');
    }
  }

  /// Troca um refresh_token salvo por uma sessão nova (access_token e
  /// refresh_token novos) — usado ao abrir o app pra manter o usuário
  /// logado sem pedir email/senha de novo.
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Sessão expirada.');
    }
  }

  /// Pede pro backend disparar o e-mail de redefinição de senha via
  /// Supabase Auth. O backend sempre devolve 200 (mesmo se o e-mail não
  /// existir), então erro aqui só acontece por falha de rede/servidor.
  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Não foi possível enviar o e-mail agora.');
    }
  }
}