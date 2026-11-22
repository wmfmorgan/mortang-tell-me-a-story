import 'package:flutter/material.dart';

import '../stories/story_date.dart';

/// Opens a year field and reports a four-digit year.
Future<void> showRiverYearJump(BuildContext context, ValueChanged<int> onYear) {
  final controller = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (context) => _JumpDialog(controller: controller, onYear: onYear),
  ).whenComplete(controller.dispose);
}

class _JumpDialog extends StatefulWidget {
  const _JumpDialog({required this.controller, required this.onYear});

  final TextEditingController controller;
  final ValueChanged<int> onYear;

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Jump to year'),
      content: TextField(
        key: const Key('river-jump-year'),
        controller: widget.controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(errorText: _error),
      ),
      actions: [
        TextButton(onPressed: _submit, child: const Text('Jump to year')),
      ],
    );
  }

  void _submit() {
    final text = widget.controller.text;
    if (text.trim().isEmpty) return;
    final message = storyYearError(text);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    final year = int.parse(text.trim());
    Navigator.of(context).pop();
    widget.onYear(year);
  }
}
