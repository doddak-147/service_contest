import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../market_risk/models/market_risk_models.dart';
import '../../stress_test/models/stress_test_models.dart';
import '../data/combined_report_api.dart';
import '../models/combined_report_models.dart';
import 'widgets/combined_report_view.dart';

class CombinedReportScreen extends StatefulWidget {
  const CombinedReportScreen({
    required this.apiClient,
    required this.financialProfile,
    required this.instrument,
    required this.periodStart,
    required this.periodEnd,
    super.key,
  });

  final ApiClient apiClient;
  final FinancialProfileInput financialProfile;
  final Instrument instrument;
  final String periodStart;
  final String periodEnd;

  @override
  State<CombinedReportScreen> createState() => _CombinedReportScreenState();
}

class _CombinedReportScreenState extends State<CombinedReportScreen> {
  late final CombinedReportApi _api;
  CombinedAnalysisResult? _result;
  String? _errorMessage;
  bool _isLoading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _api = CombinedReportApi(widget.apiClient);
    _loadReport();
  }

  Future<void> _loadReport() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _api.analyze(
        CombinedAnalysisRequest(
          financial_profile: widget.financialProfile,
          instrument: widget.instrument,
          period_start: widget.periodStart,
          period_end: widget.periodEnd,
        ),
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _errorMessage = '결합 Report 생성에 실패했습니다.');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인 × 종목 결합 Report')),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('금융체력과 종목 과거 위험을 결합하고 있습니다...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadReport, child: const Text('다시 계산')),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        CombinedReportView(result: result),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('종목 또는 기간 다시 선택'),
        ),
      ],
    );
  }
}
