import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/market_risk_repository.dart';
import '../models/market_risk_models.dart';
import 'widgets/market_risk_card.dart';

enum PeriodPreset {
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
    super.key,
  });

  final ApiClient apiClient;
  final Instrument? initialInstrument;

  @override
  State<MarketRiskScreen> createState() => _MarketRiskScreenState();
}

class _MarketRiskScreenState extends State<MarketRiskScreen> {
  late final MarketRiskRepository _repository;
  final _searchController = TextEditingController();

  static const _popularInstruments = [
    Instrument(symbol: '005930', market: 'KRX', name: '삼성전자', currency: 'KRW'),
    Instrument(
      symbol: '000660',
      market: 'KRX',
      name: 'SK하이닉스',
      currency: 'KRW',
    ),
    Instrument(symbol: '035420', market: 'KRX', name: 'NAVER', currency: 'KRW'),
    Instrument(symbol: '005380', market: 'KRX', name: '현대차', currency: 'KRW'),
    Instrument(symbol: '035720', market: 'KRX', name: '카카오', currency: 'KRW'),
  ];

  Instrument? _selectedInstrument;
  PeriodPreset _selectedPeriod = PeriodPreset.oneYear;

  List<Instrument> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingRisk = false;
  String? _errorMessage;
  MarketRiskResult? _riskResult;

  @override
  void initState() {
    super.initState();
    _repository = MarketRiskRepository(apiClient: widget.apiClient);
    if (widget.initialInstrument != null) {
      _selectedInstrument = widget.initialInstrument;
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

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      final results = await _repository.searchInstruments(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        if (results.isEmpty) {
          _errorMessage = '검색된 종목이 없습니다.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '종목 검색에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _fetchMarketRisk() async {
    final instrument = _selectedInstrument;
    if (instrument == null) return;

    setState(() {
      _isLoadingRisk = true;
      _errorMessage = null;
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
      if (!mounted) return;
      setState(() => _riskResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '과거 위험 데이터 조회에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRisk = false);
      }
    }
  }

  void _selectInstrument(Instrument instrument) {
    setState(() {
      _selectedInstrument = instrument;
      _searchResults = [];
      _searchController.text = instrument.name;
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
                    '종목의 과거 조정주가를 분석하여 역사적 최대 하락폭(MDD), '
                    '연환산 변동성, 전고점 회복 여부를 확인합니다. 미래 수익을 예측하는 것이 아니라 '
                    '과거에 겪었던 최악의 위험 수준을 파악하기 위함입니다.',
                    style: theme.textTheme.bodyMedium,
                  ),
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
                      hintText: '종목명 또는 6자리 코드 (예: 삼성전자, 005930)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _handleSearch(),
                    onChanged: (_) => setState(() {}),
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
              '주요 관심 종목',
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
                  label: Text('${inst.name} (${inst.symbol})'),
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
                    return ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${item.symbol} · ${item.market}'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _selectInstrument(item),
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
                children: PeriodPreset.values.map((preset) {
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
                }).toList(),
              ),
              const SizedBox(height: 20),
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
                    if (_selectedInstrument != null)
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
                        '조정주가 데이터 및 과거 위험 지표를 계산하고 있습니다...',
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
            if (!_isLoadingRisk && _riskResult != null)
              MarketRiskCard(result: _riskResult!),
          ],
        ),
      ),
    );
  }
}
