import 'package:flutter/material.dart';

import '../../../../shared/api/api_client.dart';
import '../../../../shared/config/app_config.dart';
import '../../../../shared/theme/app_theme.dart';

enum _ConnectionStatus { checking, online, offline }

class ServerStatusCard extends StatefulWidget {
  const ServerStatusCard({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ServerStatusCard> createState() => _ServerStatusCardState();
}

class _ServerStatusCardState extends State<ServerStatusCard> {
  _ConnectionStatus _status = _ConnectionStatus.checking;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _status = _ConnectionStatus.checking;
      _errorMessage = null;
    });

    try {
      final health = await widget.apiClient.getJson('/health');
      if (health['status'] != 'ok') {
        throw const ApiException(
          code: 'INVALID_HEALTH_RESPONSE',
          message: '알 수 없는 서버 상태입니다.',
        );
      }
      if (mounted) {
        setState(() => _status = _ConnectionStatus.online);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = _ConnectionStatus.offline;
          _errorMessage = error is ApiException
              ? error.message
              : '서버에 연결할 수 없습니다.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChecking = _status == _ConnectionStatus.checking;
    final (label, description, foreground, background) = switch (_status) {
      _ConnectionStatus.checking => (
        '확인 중',
        'FastAPI 서버의 응답을 기다리고 있습니다.',
        AppColors.pending,
        AppColors.pendingBackground,
      ),
      _ConnectionStatus.online => (
        '연결됨',
        'FastAPI 서버가 정상적으로 응답했습니다.',
        AppColors.success,
        AppColors.successBackground,
      ),
      _ConnectionStatus.offline => (
        '연결 실패',
        '서버 주소와 실행 상태를 확인해 주세요.',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '서버 연결 상태',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Semantics(
                  label: '서버 상태: $label',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_errorMessage ?? description),
            const SizedBox(height: 8),
            SelectableText(
              '${AppConfig.apiBaseUrl}/health',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: isChecking ? null : _checkConnection,
              child: Text(isChecking ? '확인 중…' : '다시 확인'),
            ),
          ],
        ),
      ),
    );
  }
}
