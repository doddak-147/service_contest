import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../market_risk/models/market_risk_models.dart';
import '../../stress_test/models/stress_test_models.dart';
import '../data/combined_report_api.dart';
import '../data/explanation_api.dart';
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
  late final ExplanationApi _explanationApi;
  CombinedAnalysisResult? _result;
  ExplanationResult? _explanation;
  String? _errorMessage;
  String? _explanationError;
  bool _isLoading = false;
  bool _isLoadingExplanation = false;
  int _requestId = 0;
  int _explanationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _api = CombinedReportApi(widget.apiClient);
    _explanationApi = ExplanationApi(widget.apiClient);
    _loadReport();
  }

  Future<void> _loadReport() async {
    final requestId = ++_requestId;
    _explanationRequestId++;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _explanation = null;
      _explanationError = null;
      _isLoadingExplanation = false;
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
      unawaited(_loadExplanation(result));
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

  Future<void> _loadExplanation(CombinedAnalysisResult result) async {
    final scenario = result.mdd_impact ?? _findDown20(result.scenarios);
    if (scenario == null) {
      setState(() => _explanationError = '설명할 수 있는 시나리오 결과가 없습니다.');
      return;
    }

    final requestId = ++_explanationRequestId;
    setState(() {
      _isLoadingExplanation = true;
      _explanationError = null;
      _explanation = null;
    });

    try {
      final explanation = await _explanationApi.explain(
        ExplanationInput(
          scenario_key: scenario.scenario_key,
          assumed_return_rate: scenario.assumed_return_rate,
          investment_loss_krw: scenario.investment_loss_krw,
          loss_to_equity_ratio: scenario.loss_to_equity_ratio,
          loss_to_emergency_fund_ratio: scenario.loss_to_emergency_fund_ratio,
          loss_to_monthly_fixed_expenses:
              scenario.loss_to_monthly_fixed_expenses,
          net_investment_equity_krw: scenario.net_investment_equity_krw,
          estimated_monthly_interest_krw:
              scenario.estimated_monthly_interest_krw,
          market_max_drawdown_rate: result.market_risk?.max_drawdown_rate,
          warnings: result.warnings,
        ),
      );
      if (!mounted || requestId != _explanationRequestId) return;
      setState(() => _explanation = explanation);
    } on ApiException catch (error) {
      if (!mounted || requestId != _explanationRequestId) return;
      setState(() => _explanationError = error.message);
    } catch (_) {
      if (!mounted || requestId != _explanationRequestId) return;
      setState(() => _explanationError = '결과 설명을 불러오지 못했습니다.');
    } finally {
      if (mounted && requestId == _explanationRequestId) {
        setState(() => _isLoadingExplanation = false);
      }
    }
  }

  ScenarioResult? _findDown20(List<ScenarioResult> scenarios) {
    for (final scenario in scenarios) {
      if (scenario.scenario_key == ScenarioKeys.down20) {
        return scenario;
      }
    }
    return scenarios.isEmpty ? null : scenarios.first;
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
        CombinedReportView(
          result: result,
          explanation: _explanation,
          explanationError: _explanationError,
          isExplanationLoading: _isLoadingExplanation,
          onRetryExplanation: () => _loadExplanation(result),
        ),
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
