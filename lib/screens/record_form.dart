import 'package:flutter/material.dart';

import '../api_client.dart';
import '../main.dart';
import '../models.dart';
import '../widgets.dart';

/// Admin: add a new CS record, or edit an existing one.
class RecordFormScreen extends StatefulWidget {
  final CsRecord? existing;
  const RecordFormScreen({super.key, this.existing});

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _violation;
  late final TextEditingController _hours;
  late final TextEditingController _rendered;
  String? _studentId;
  DateTime? _date;
  TimeOfDay? _time;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _violation = TextEditingController(text: r?.violation ?? '');
    _hours = TextEditingController(
      text: r == null ? '' : hoursText(r.hoursRequired),
    );
    _rendered = TextEditingController(
      text: r == null ? '0' : hoursText(r.hoursRendered),
    );
    _studentId = r?.studentId;
    _date = r?.dutyDate;
  }

  @override
  void dispose() {
    _violation.dispose();
    _hours.dispose();
    _rendered.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final timeText = _time?.format(context) ?? widget.existing?.dutyTime ?? '';
    final hrs = double.parse(_hours.text.trim());

    try {
      if (_editing) {
        final r = widget.existing!;
        r.studentId = _studentId!;
        r.violation = _violation.text.trim();
        r.hoursRequired = hrs;
        r.hoursRendered = double.parse(_rendered.text.trim());
        r.dutyDate = _date;
        r.dutyTime = timeText;
        await store.saveRecord(r);
      } else {
        await store.addRecord(
          studentId: _studentId!,
          violation: _violation.text,
          hoursRequired: hrs,
          dutyDate: _date,
          dutyTime: timeText,
        );
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = store.students;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit record' : 'Add record')),
      body: students.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No students are registered yet. '
                  'Register a student account first.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _studentId,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: students
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.studentNo})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _studentId = v),
                    validator: (v) => v == null ? 'Select a student' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _violation,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Violation'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hours,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Required CS hours',
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      return (n == null || n <= 0)
                          ? 'Enter a valid number of hours'
                          : null;
                    },
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _rendered,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Hours rendered',
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return (n == null || n < 0) ? 'Invalid' : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            _date == null
                                ? 'Duty date'
                                : dateFmt.format(_date!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            _time?.format(context) ??
                                (widget.existing?.dutyTime.isNotEmpty == true
                                    ? widget.existing!.dutyTime
                                    : 'Duty time'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_editing ? 'Save changes' : 'Create record'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
