import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../combined_report/presentation/combined_report_screen.dart';
import '../../stress_test/models/stress_test_models.dart';
import '../../stress_test/presentation/stress_test_screen.dart';
import '../data/market_risk_repository.dart';
import '../models/market_risk_models.dart';
import 'widgets/market_risk_card.dart';

enum PeriodPreset {
  threeMonths(label: '최근 3개월', days: 90),
  oneYear(label: '최근 1년', days: 365),
  threeYears(label: '최근 3년', days: 365 * 3),
  fiveYears(label: '최근 5년', days: 365 * 5);

  const PeriodPreset({required this.label, required this.days});
  final String label;
  final int days;
}

class MarketRiskScreen extends StatefulWidget {
  const MarketRiskScreen({
    required this.apiClient,
    this.initialInstrument,
    this.financialProfile,
    this.isExampleProfile = false,
    super.key,
  });

  final ApiClient apiClient;
  final Instrument? initialInstrument;
  final FinancialProfileInput? financialProfile;
  final bool isExampleProfile;

  @override
  State<MarketRiskScreen> createState() => _MarketRiskScreenState();
}

class _MarketRiskScreenState extends State<MarketRiskScreen> {
  late final MarketRiskRepository _repository;
  final _searchController = TextEditingController();

  static const _popularInstruments = [
    Instrument(
      symbol: 'AAPL',
      market: 'NASDAQ',
      name: 'Apple',
      currency: 'USD',
    ),
    Instrument(
      symbol: 'MSFT',
      market: 'NASDAQ',
      name: 'Microsoft',
      currency: 'USD',
    ),
    Instrument(
      symbol: 'NVDA',
      market: 'NASDAQ',
      name: 'NVIDIA',
      currency: 'USD',
    ),
    Instrument(
      symbol: 'TSLA',
      market: 'NASDAQ',
      name: 'Tesla',
      currency: 'USD',
    ),
    Instrument(
      symbol: 'SPY',
      market: 'NYSE',
      name: 'SPY ETF',
      currency: 'USD',
      instrument_type: 'etf',
    ),
    Instrument(
      symbol: 'QQQ',
      market: 'NASDAQ',
      name: 'QQQ ETF',
      currency: 'USD',
      instrument_type: 'etf',
    ),
  ];

  Instrument? _selectedInstrument;
  PeriodPreset _selectedPeriod = PeriodPreset.oneYear;

  List<Instrument> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingRisk = false;
  String? _errorMessage;
  MarketRiskResult? _riskResult;
  bool _showRiskRetry = false;
  int _searchRequestId = 0;
  int _riskRequestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = MarketRiskRepository(apiClient: widget.apiClient);
    if (widget.initialInstrument != null) {
      _selectedInstrument = widget.initialInstrument;
      if (widget.initialInstrument!.currency == 'USD') {
        _selectedPeriod = PeriodPreset.threeMonths;
      }
      _fetchMarketRisk();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults = [];
      _showRiskRetry = false;
    });

    try {
      final results = await _repository.searchInstruments(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = results;
        if (results.isEmpty) {
          _errorMessage = '검색된 종목이 없습니다.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _errorMessage = '종목 검색에 실패했습니다.');
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _handleSearchTextChanged(String _) {
    _searchRequestId++;
    setState(() {
      _searchResults = [];
      _isSearching = false;
      if (!_showRiskRetry) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _fetchMarketRisk() async {
    final instrument = _selectedInstrument;
    if (instrument == null) return;
    final requestId = ++_riskRequestId;

    setState(() {
      _isLoadingRisk = true;
      _errorMessage = null;
      _riskResult = null;
      _showRiskRetry = false;
    });

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedPeriod.days));

    try {
      final result = await _repository.getMarketRisk(
        market: instrument.market,
        symbol: instrument.symbol,
        startDate: startDate,
        endDate: now,
      );
      if (!mounted || requestId != _riskRequestId) return;
      setState(() => _riskResult = result);
    } on ApiException catch (e) {
      if (!mounted || requestId != _riskRequestId) return;
      setState(() {
        _errorMessage = e.message;
        _showRiskRetry = true;
      });
    } catch (_) {
      if (!mounted || requestId != _riskRequestId) return;
      setState(() {
        _errorMessage = '과거 위험 데이터 조회에 실패했습니다.';
        _showRiskRetry = true;
      });
    } finally {
      if (mounted && requestId == _riskRequestId) {
        setState(() => _isLoadingRisk = false);
      }
    }
  }

  void _selectInstrument(Instrument instrument) {
    _searchRequestId++;
    setState(() {
      _selectedInstrument = instrument;
      _selectedPeriod = instrument.currency == 'USD'
          ? PeriodPreset.threeMonths
          : PeriodPreset.oneYear;
      _searchResults = [];
      _searchController.text = instrument.name;
      _riskResult = null;
      _errorMessage = null;
      _showRiskRetry = false;
    });
    _fetchMarketRisk();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '종목 과거 위험 분석',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Guidance banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '과거 위험 분석이란?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '종목의 과거 가격을 분석하여 관측 기간의 최대 하락폭(MDD), '
                    '연환산 변동성, 전고점 회복 여부를 확인합니다. 미래 수익을 예측하는 것이 아니라 '
                    '과거에 겪었던 최악의 위험 수준을 파악하기 위함입니다.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '현재 실제 시세 분석은 미국 상장 주식과 ETF를 지원합니다. '
                    '국내 종목 시세는 제공하지 않습니다.',
                  ),
                  const SizedBox(height: 8),
                  const Text('ETF는 지수 자체가 아니며 배당을 제외한 시장가격 변동만 분석합니다.'),
                  const SizedBox(height: 8),
                  const Text('한글 검색은 애플·마이크로소프트·큐큐큐 등 일부 종목만 지원합니다.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            const Text(
              '종목 검색',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '미국 주식·ETF (예: 애플, SPY)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchRequestId++;
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _isSearching = false;
                                  _errorMessage = null;
                                  _showRiskRetry = false;
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _handleSearch(),
                    onChanged: _handleSearchTextChanged,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSearching ? null : _handleSearch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 52),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Text('검색'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Popular Quick Chips
            const Text(
              '주식·ETF 빠른 선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularInstruments.map((inst) {
                final isSelected = _selectedInstrument?.symbol == inst.symbol;
                return ChoiceChip(
                  label: Text(
                    inst.instrument_type == 'etf'
                        ? '${inst.symbol} · ETF'
                        : '${inst.name} (${inst.symbol})',
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _selectInstrument(inst);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Search Results
            if (_searchResults.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${item.symbol} · ${item.market} · '
                          '${item.instrument_type == 'etf' ? 'ETF' : '주식'}',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _selectInstrument(item),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Period Selector (Only if instrument selected)
            if (_selectedInstrument != null) ...[
              const Text(
                '분석 기간 선택',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children:
                    (_selectedInstrument!.currency == 'USD'
                            ? [PeriodPreset.threeMonths]
                            : PeriodPreset.values.where(
                                (preset) => preset != PeriodPreset.threeMonths,
                              ))
                        .map((preset) {
                          final isSelected = _selectedPeriod == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(preset.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected && _selectedPeriod != preset) {
                                  setState(() => _selectedPeriod = preset);
                                  _fetchMarketRisk();
                                }
                              },
                            ),
                          );
                        })
                        .toList(),
              ),
              const SizedBox(height: 20),
              if (_selectedInstrument!.currency == 'USD') ...[
                const Text(
                  '미국 종목은 최근 3개월의 일별 시세와 원/달러 기준환율을 결합해 분석합니다. '
                  '긴 기간의 위험을 대표하지 않습니다.',
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Error banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_showRiskRetry && _selectedInstrument != null)
                      TextButton(
                        onPressed: _fetchMarketRisk,
                        child: const Text('재시도'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Loading Indicator
            if (_isLoadingRisk)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '과거 가격과 환율을 확인하고 위험 지표를 계산하고 있습니다...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Result Card
            if (!_isLoadingRisk && _riskResult != null) ...[
              MarketRiskCard(result: _riskResult!),
              if (widget.financialProfile != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final result = _riskResult!;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CombinedReportScreen(
                          apiClient: widget.apiClient,
                          financialProfile: widget.financialProfile!,
                          isExampleProfile: widget.isExampleProfile,
                          instrument: result.instrument,
                          periodStart: result.period_start,
                          periodEnd: result.period_end,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('개인 × 종목 결합 Report 보기'),
                ),
              ],
              if (_riskResult!.max_drawdown_rate != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    final result = _riskResult!;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StressTestScreen(
                          apiClient: widget.apiClient,
                          initialProfile: widget.financialProfile,
                          isExampleProfile: widget.isExampleProfile,
                          historicalMddRate: result.max_drawdown_rate,
                          historicalMddSource: result.instrument.name,
                          instrumentCurrency: result.instrument.currency,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('이 MDD로 Stress Test 진행'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
