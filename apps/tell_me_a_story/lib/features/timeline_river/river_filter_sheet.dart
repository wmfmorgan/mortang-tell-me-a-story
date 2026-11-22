import 'package:flutter/material.dart';

import 'river_filter.dart';
import 'river_filter_options.dart';
import 'river_filter_panel.dart';

/// Phone filter sheet. It keeps its own copy so chips update while it is open.
class RiverFilterSheet extends StatefulWidget {
  const RiverFilterSheet({
    super.key,
    required this.filter,
    required this.options,
    required this.matched,
    required this.total,
    required this.onChanged,
  });

  final RiverFilter filter;
  final RiverFilterOptions options;
  final int matched;
  final int total;
  final ValueChanged<RiverFilter> onChanged;

  @override
  State<RiverFilterSheet> createState() => _RiverFilterSheetState();
}

class _RiverFilterSheetState extends State<RiverFilterSheet> {
  late RiverFilter _filter = widget.filter;

  @override
  void didUpdateWidget(covariant RiverFilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: RiverFilterPanel(
        filter: _filter,
        options: widget.options,
        matched: widget.matched,
        total: widget.total,
        onChanged: _set,
      ),
    );
  }

  void _set(RiverFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }
}
