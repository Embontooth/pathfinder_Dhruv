import 'package:flutter/material.dart';
import 'package:path_finder/providers/user_provider.dart';
import 'package:path_finder/services/token_service.dart';
import 'package:provider/provider.dart';

class LogoutService {
  final TokenService _tokenService = TokenService();

  Future<void> logout(BuildContext context) async {
    try {
      // Clear the stored token and role
      await _tokenService.logout();
      context.read<UserProvider>().clearUserData();
      // Navigate to the start page and clear the navigation stack
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/signin', (route) => false);
    } catch (e) {
      print('Logout error: $e');
      // Handle error (could show a snackbar or alert)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }
}
