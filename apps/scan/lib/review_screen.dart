import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'strings.dart';

/// "Is it right?": the recognised tasks next to the photo, every number
/// editable. Returns the packet's source name and tasks, or null.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.tasks,
    this.photo,
    this.note,
  });

  final List<Task> tasks;
  final Uint8List? photo;

  /// A remark about the page (nothing found, unknown task types).
  final String? note;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class ReviewResult {
  const ReviewResult(this.source, this.tasks);
  final String source;
  final List<Task> tasks;
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<Task> _tasks = [...widget.tasks];
  final _source = TextEditingController();
  bool _photoOpen = true;

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _edit(int? i) async {
    final t = await showDialog<Task>(
      context: context,
      builder: (_) => _EditTask(task: i == null ? null : _tasks[i]),
    );
    if (t == null) return;
    setState(() {
      if (i == null) {
        _tasks.add(t);
      } else {
        _tasks[i] = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('check'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tasks.isEmpty
            ? null
            : () => Navigator.of(context).pop(
                ReviewResult(_source.text.trim(), _renumber(_tasks)),
              ),
        icon: const Icon(Icons.qr_code_2),
        label: Text(tr('send')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          if (widget.photo != null)
            GestureDetector(
              onTap: () => setState(() => _photoOpen = !_photoOpen),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: _photoOpen ? 320 : 80,
                    width: double.infinity,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(widget.photo!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(tr('check_text')),
          if (widget.note != null)
            Card(
              color: const Color(0xFFFFF4D6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.note!),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _source,
            decoration: InputDecoration(labelText: tr('source')),
          ),
          const SizedBox(height: 8),
          Text(
            tr('found', {'n': _tasks.length}),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (var i = 0; i < _tasks.length; i++)
            Dismissible(
              key: ObjectKey(_tasks[i]),
              onDismissed: (_) => setState(() => _tasks.removeAt(i)),
              background: Container(color: Colors.red.shade100),
              child: _TaskTile(task: _tasks[i], onTap: () => _edit(i)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: Text(tr('add_task')),
          ),
        ],
      ),
    );
  }
}

List<Task> _renumber(List<Task> ts) => [
  for (var i = 0; i < ts.length; i++)
    Task.fromJson({...ts[i].toJson(), 'n': '${i + 1}'}),
];

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = task.warnings;
    final t = task;
    return Card(
      color: w.isEmpty ? null : const Color(0xFFFFE3D6),
      child: ListTile(
        onTap: onTap,
        title: Text(
          t.format(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        subtitle: t is StepsTask
            ? Text(t.lines.skip(1).join('   '))
            : w.isEmpty
            ? null
            : Text(w.map(warning).join(', ')),
        trailing: t is StepsTask
            ? Chip(label: Text(tr('type_steps')))
            : const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _EditTask extends StatefulWidget {
  const _EditTask({this.task});
  final Task? task;

  @override
  State<_EditTask> createState() => _EditTaskState();
}

class _EditTaskState extends State<_EditTask> {
  late final _text = TextEditingController(
    text: switch (widget.task) {
      final EqTask t => t.compact,
      final StepsTask t => '${t.a}${t.op.symbol}${t.b}',
      _ => '',
    },
  );
  late bool _steps = widget.task is StepsTask;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final e = EqTask.parse(_text.text);
      final Task t;
      if (_steps) {
        if (e.a == null || e.b == null || e.op == Op.mul) {
          throw const FormatException();
        }
        t = StepsTask(e.a!, e.op, e.b!);
      } else {
        t = e;
      }
      t.questions; // throws on nonsense like ?+?
      Navigator.of(context).pop(t);
    } catch (_) {
      setState(() => _error = tr('bad_task'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('edit_task')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            style: const TextStyle(fontSize: 24),
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(errorText: _error, hintText: '8+5'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr('type_eq'))),
              ButtonSegment(value: true, label: Text(tr('type_steps'))),
            ],
            selected: {_steps},
            onSelectionChanged: (s) => setState(() => _steps = s.first),
          ),
          const SizedBox(height: 8),
          Text(tr('edit_help'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(tr('save'))),
      ],
    );
  }
}
