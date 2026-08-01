import 'package:flutter/material.dart';

import '../services/converter_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  bool _isCurrency = false;

  // Unit converter state
  UnitCategory _category = UnitCategory.length;
  String _fromUnit = 'Meter';
  String _toUnit = 'Foot';
  final _fromController = TextEditingController(text: '1');
  double _unitResult = 0;

  // Currency converter state
  String _fromCurrency = 'USD';
  String _toCurrency = 'EUR';
  final _currencyController = TextEditingController(text: '100');
  double _currencyResult = 0;
  bool _isLiveRate = true;
  DateTime? _rateFetchedAt;
  bool _loadingRate = false;
  String? _rateError;
  double _lastRate = 1;

  @override
  void initState() {
    super.initState();
    _recalculateUnit();
    _fetchCurrencyRate();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _recalculateUnit() {
    final value = double.tryParse(_fromController.text) ?? 0;
    setState(() => _unitResult = ConverterService.convertUnit(_category, _fromUnit, _toUnit, value));
  }

  Future<void> _fetchCurrencyRate() async {
    setState(() {
      _loadingRate = true;
      _rateError = null;
    });
    try {
      final result = await ConverterService.getRate(_fromCurrency, _toCurrency);
      final value = double.tryParse(_currencyController.text) ?? 0;
      setState(() {
        _lastRate = result.rate;
        _currencyResult = value * result.rate;
        _isLiveRate = result.isLive;
        _rateFetchedAt = result.fetchedAt;
        _loadingRate = false;
      });
    } catch (e) {
      setState(() {
        _loadingRate = false;
        _rateError = '$e';
      });
    }
  }

  void _setCategory(UnitCategory category) {
    final units = ConverterService.unitsFor(category).keys.toList();
    setState(() {
      _category = category;
      _fromUnit = units[0];
      _toUnit = units.length > 1 ? units[1] : units[0];
    });
    _recalculateUnit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Converter', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _tab(context, 'Unit', Icons.straighten_rounded, !_isCurrency, () => setState(() => _isCurrency = false)),
                  _tab(context, 'Currency', Icons.currency_exchange_rounded, _isCurrency, () => setState(() => _isCurrency = true)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_isCurrency) ...[
              _ConverterCard(
                label: 'From',
                controller: _fromController,
                unit: _fromUnit,
                unitOptions: ConverterService.unitsFor(_category).keys.toList(),
                onValueChanged: (_) => _recalculateUnit(),
                onUnitChanged: (u) {
                  setState(() => _fromUnit = u);
                  _recalculateUnit();
                },
              ),
              Center(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final tmp = _fromUnit;
                      _fromUnit = _toUnit;
                      _toUnit = tmp;
                    });
                    _recalculateUnit();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.convertSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.swap_vert_rounded, color: AppColors.convertPrimary),
                  ),
                ),
              ),
              _ConverterCard(
                label: 'To',
                value: _formatNumber(_unitResult),
                unit: _toUnit,
                readOnly: true,
                unitOptions: ConverterService.unitsFor(_category).keys.toList(),
                onUnitChanged: (u) {
                  setState(() => _toUnit = u);
                  _recalculateUnit();
                },
              ),
              const SizedBox(height: 24),
              Text('Category', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UnitCategory.values.map((c) {
                  return ChoiceChip(
                    label: Text(_categoryLabel(c)),
                    selected: _category == c,
                    onSelected: (_) => _setCategory(c),
                  );
                }).toList(),
              ),
            ] else ...[
              _ConverterCard(
                label: 'From',
                controller: _currencyController,
                unit: _fromCurrency,
                unitOptions: ConverterService.currencies,
                onValueChanged: (v) {
                  final value = double.tryParse(v) ?? 0;
                  setState(() => _currencyResult = value * _lastRate);
                },
                onUnitChanged: (u) {
                  setState(() => _fromCurrency = u);
                  _fetchCurrencyRate();
                },
              ),
              Center(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final tmp = _fromCurrency;
                      _fromCurrency = _toCurrency;
                      _toCurrency = tmp;
                    });
                    _fetchCurrencyRate();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.convertSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.swap_vert_rounded, color: AppColors.convertPrimary),
                  ),
                ),
              ),
              _ConverterCard(
                label: 'To',
                value: _loadingRate ? '…' : _formatNumber(_currencyResult),
                unit: _toCurrency,
                readOnly: true,
                unitOptions: ConverterService.currencies,
                onUnitChanged: (u) {
                  setState(() => _toCurrency = u);
                  _fetchCurrencyRate();
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.convertSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _rateError != null
                          ? Icons.wifi_off_rounded
                          : (_isLiveRate ? Icons.wifi_rounded : Icons.cloud_off_rounded),
                      size: 18,
                      color: AppColors.convertPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _rateError != null
                            ? _rateError!
                            : (_isLiveRate
                                ? 'Live exchange rate'
                                : 'Offline — showing last saved rate${_rateFetchedAt != null ? ' from ${_rateFetchedAt!.toLocal()}' : ''}'),
                        style: AppTextStyles.bodySmall(theme.colorScheme.onSurface),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.convertPrimary),
                      onPressed: _fetchCurrencyRate,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _categoryLabel(UnitCategory c) => switch (c) {
        UnitCategory.length => 'Length',
        UnitCategory.weight => 'Weight',
        UnitCategory.area => 'Area',
        UnitCategory.volume => 'Volume',
        UnitCategory.temperature => 'Temperature',
        UnitCategory.speed => 'Speed',
      };

  String _formatNumber(double value) {
    if (value.abs() >= 1000) return value.toStringAsFixed(2);
    if (value.abs() >= 1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(5);
  }

  Widget _tab(BuildContext context, String label, IconData icon, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? AppColors.cardShadow(theme.brightness, tint: AppColors.convertPrimary) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.convertPrimary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: AppTextStyles.label(selected ? AppColors.convertPrimary : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConverterCard extends StatelessWidget {
  final String label;
  final String? value;
  final TextEditingController? controller;
  final String unit;
  final bool readOnly;
  final List<String>? unitOptions;
  final ValueChanged<String>? onValueChanged;
  final ValueChanged<String> onUnitChanged;

  const _ConverterCard({
    required this.label,
    this.value,
    this.controller,
    required this.unit,
    this.readOnly = false,
    this.unitOptions,
    this.onValueChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: readOnly ? AppColors.cardShadow(theme.brightness, tint: AppColors.convertPrimary) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                readOnly
                    ? Text(value ?? '', style: AppTextStyles.displayMedium(theme.colorScheme.onSurface))
                    : TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        style: AppTextStyles.displayMedium(theme.colorScheme.onSurface),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        onChanged: onValueChanged,
                      ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            initialValue: unit,
            onSelected: onUnitChanged,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => (unitOptions ?? [unit])
                .map((u) => PopupMenuItem(value: u, child: Text(u)))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.convertSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit, style: AppTextStyles.label(AppColors.convertPrimary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.convertPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
