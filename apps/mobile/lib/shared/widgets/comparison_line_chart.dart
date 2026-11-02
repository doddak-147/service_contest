import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LineSeries {
  const LineSeries(this.label, this.color, this.values);
  final String label;
  final Color color;
  final List<double?> values;
}

/// Plots server values only. Missing values break a line; they are not interpolated.
class ComparisonLineChart extends StatefulWidget {
  const ComparisonLineChart({
    required this.title,
    required this.labels,
    required this.series,
    required this.unit,
    this.markers = const {},
    this.includeZero = true,
    this.highlightStart,
    this.highlightEnd,
    super.key,
  });
  final String title, unit;
  final List<String> labels;
  final List<LineSeries> series;
  final Map<int, String> markers;
  final bool includeZero;
  final int? highlightStart, highlightEnd;
  @override
  State<ComparisonLineChart> createState() => _ComparisonLineChartState();
}

class _ComparisonLineChartState extends State<ComparisonLineChart> {
  int? _selected;
  @override
  Widget build(BuildContext context) {
    final values = widget.series
        .expand((s) => s.values)
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (widget.labels.isEmpty || values.isEmpty) {
      return const Text('표시할 그래프 데이터가 없습니다.');
    }
    final index = (_selected ?? widget.labels.length - 1).clamp(
      0,
      widget.labels.length - 1,
    );
    var low = widget.includeZero
        ? math.min(0.0, values.reduce(math.min))
        : values.reduce(math.min);
    var high = values.reduce(math.max);
    if (high <= low) high = low + 1;
    final pad = (high - low) * .08;
    low -= pad;
    high += pad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: widget.series
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.horizontal_rule, color: s.color, size: 22),
                    const SizedBox(width: 4),
                    Flexible(child: Text(s.label)),
                  ],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '단위: ${widget.unit} · 그래프를 눌러 시점을 확인하세요.',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final value in [high, (high + low) / 2, low])
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value.toStringAsFixed(1),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    onTapDown: (details) => setState(
                      () => _selected =
                          (details.localPosition.dx /
                                  box.maxWidth *
                                  (widget.labels.length - 1))
                              .round()
                              .clamp(0, widget.labels.length - 1),
                    ),
                    child: Semantics(
                      label: '${widget.title}. ${widget.labels[index]} 선택됨.',
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _Lines(
                          widget.series,
                          widget.labels.length,
                          low,
                          high,
                          index,
                          widget.markers,
                          widget.highlightStart,
                          widget.highlightEnd,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.labels.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                widget.labels.last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            [
              widget.labels[index],
              if (widget.markers[index] != null) widget.markers[index]!,
              ...widget.series.map(
                (s) =>
                    '${s.label}: ${index < s.values.length && s.values[index] != null ? s.values[index]!.toStringAsFixed(2) : '자료 없음'} ${widget.unit}',
              ),
            ].join(' · '),
          ),
        ),
      ],
    );
  }
}

class _Lines extends CustomPainter {
  _Lines(
    this.series,
    this.count,
    this.low,
    this.high,
    this.selected,
    this.markers,
    this.highlightStart,
    this.highlightEnd,
  );
  final List<LineSeries> series;
  final int count, selected;
  final double low, high;
  final Map<int, String> markers;
  final int? highlightStart, highlightEnd;
  @override
  void paint(Canvas canvas, Size size) {
    double x(int index) =>
        count < 2 ? size.width / 2 : size.width * index / (count - 1);
    double y(double value) => size.height * (1 - (value - low) / (high - low));
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    if (highlightStart != null &&
        highlightEnd != null &&
        highlightStart! >= 0 &&
        highlightEnd! >= highlightStart! &&
        highlightEnd! < count) {
      canvas.drawRect(
        Rect.fromLTRB(x(highlightStart!), 0, x(highlightEnd!), size.height),
        Paint()..color = AppColors.danger.withValues(alpha: .10),
      );
    }
    for (var i = 0; i < 5; i++) {
      final height = size.height * i / 4;
      canvas.drawLine(Offset(0, height), Offset(size.width, height), grid);
    }
    if (low < 0 && high > 0) {
      canvas.drawLine(
        Offset(0, y(0)),
        Offset(size.width, y(0)),
        Paint()..color = AppColors.textMuted,
      );
    }
    for (final marker in markers.keys) {
      canvas.drawLine(
        Offset(x(marker), 0),
        Offset(x(marker), size.height),
        grid,
      );
      final label = TextPainter(
        text: TextSpan(
          text: markers[marker],
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.min(80, size.width));
      label.paint(
        canvas,
        Offset(
          (x(marker) - label.width / 2)
              .clamp(0, math.max(0, size.width - label.width))
              .toDouble(),
          3,
        ),
      );
    }
    for (final s in series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < math.min(count, s.values.length); i++) {
        final value = s.values[i];
        if (value == null || !value.isFinite) {
          started = false;
          continue;
        }
        if (!started) {
          path.moveTo(x(i), y(value));
          started = true;
        } else {
          path.lineTo(x(i), y(value));
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      if (selected < s.values.length && s.values[selected] != null) {
        canvas.drawCircle(
          Offset(x(selected), y(s.values[selected]!)),
          4,
          Paint()..color = s.color,
        );
      }
    }
    canvas.drawLine(
      Offset(x(selected), 0),
      Offset(x(selected), size.height),
      Paint()..color = AppColors.textMuted.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(covariant _Lines oldDelegate) => true;
}
