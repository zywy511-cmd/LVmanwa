import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'register_page.dart' show RegisterPrefill;

/// 拷贝漫画注册页：调用 COPY App 接口 /api/v3/register，
/// 用户名 6-36 位，注册成功后回填登录页。
class CopyRegisterPage extends StatefulWidget {
  const CopyRegisterPage({super.key});

  @override
  State<CopyRegisterPage> createState() => _CopyRegisterPageState();
}

class _CopyRegisterPageState extends State<CopyRegisterPage> {
  final _api = ApiClient();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = l10n.profileRegisterInfoRequired);
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = l10n.profilePasswordMismatch);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _api.user.copyRegister(username: username, password: password);
      if (!mounted) return;
      Navigator.pop(
        context,
        RegisterPrefill(username: username, password: password),
      );
    } catch (e) {
      String msg = l10n.profileRegisterFailed;
      if (e is DioException) {
        msg = e.message ?? msg;
        if (e.response?.data is Map) {
          final data = e.response?.data as Map;
          final results = data['results'];
          msg =
              data['message']?.toString() ??
              data['detail']?.toString() ??
              (results is Map ? results['detail']?.toString() : null) ??
              msg;
        }
      }
      if (!mounted) return;
      setState(() {
        _error = msg;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth.clamp(0.0, 420.0);
    final hp = (screenWidth - contentWidth) / 2;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileRegisterCopyMangaAccountButton),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hp + 24, 24, hp + 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileCopyUsernameLengthHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: l10n.profileUsernameLabel,
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: AppRadius.mdR),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.profilePasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(borderRadius: AppRadius.mdR),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.profileConfirmPasswordLabel,
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.mdR),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitting ? null : _register(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _submitting ? null : _register,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l10n.profileRegisterButton,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
