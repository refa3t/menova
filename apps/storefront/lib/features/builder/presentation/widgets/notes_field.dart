import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';

/// Customer notes on the item (P1-C06), stored in the Selection.
class NotesField extends StatefulWidget {
  const NotesField({super.key, required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<NotesField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(NotesField old) {
    super.didUpdateWidget(old);
    // Follow external resets without fighting the user's typing.
    if (widget.initial != _controller.text) _controller.text = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLength: 200,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: AppStrings.notes,
        hintText: AppStrings.notesHint,
        border: OutlineInputBorder(),
      ),
    );
  }
}
