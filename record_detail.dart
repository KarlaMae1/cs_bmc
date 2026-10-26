import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../widgets.dart';
import 'record_form.dart';

/// Digital CS ticket. Students can view it and reschedule their duty.
/// Admins can edit, log hours, and delete.
class RecordDetailScreen extends StatelessWidget {
  final String recordId;
  const RecordDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final matches = store.records.where((r) => r.id == recordId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Hindi na mahanap ang record.')),
          );
        }
        final r = matches.first;
        final isAdmin = store.current!.isAdmin;
        final cs = Theme.of(context).colorScheme;
        final student = store.userById(r.studentId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('CS Ticket'),
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecordFormScreen(existing: r)),
                  ),
                ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(context, r),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: cs.primary,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMMUNITY SERVICE TICKET',
                              style: TextStyle(
                                  color: cs.onPrimary.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(r.ticketNo,
                              style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Student', student?.name ?? 'Unknown'),
                          _row('Student no.', student?.studentNo ?? '-'),
                          _row('Violation', r.violation),
                          _row('Issued', dateFmt.format(r.createdAt)),
                          const Divider(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              StatusChip(r.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: r.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${hoursText(r.hoursRendered)} of ${hoursText(r.hoursRequired)} hrs rendered '
                            '(${hoursText(r.remaining)} hrs remaining)',
                          ),
                          const Divider(height: 28),
                          _row(
                              'Duty date',
                              r.dutyDate == null
                                  ? 'Hindi pa naka-schedule'
                                  : dateFmt.format(r.dutyDate!)),
                          _row('Duty time',
                              r.dutyTime.isEmpty ? '-' : r.dutyTime),
                          if (r.note.isNotEmpty) _row('Reschedule note', r.note),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (r.status != 'Completed')
                FilledButton.icon(
                  onPressed: () => _reschedule(context, r),
                  icon: const Icon(Icons.event_repeat),
                  label: Text(r.dutyDate == null
                      ? 'Mag-schedule ng duty'
                      : 'I-reschedule ang duty'),
                ),
              if (isAdmin && r.status != 'Completed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addHours(context, r),
                  icon: const Icon(Icons.more_time),
                  label: const Text('Mag-add ng rendered hours'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> _reschedule(BuildContext context, CsRecord r) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: (r.dutyDate != null && r.dutyDate!.isAfter(now))
          ? r.dutyDate!
          : now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Bagong petsa ng duty',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Bagong oras ng duty',
    );
    if (time == null || !context.mounted) return;

    final reasonCtrl = TextEditingController(text: r.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dahilan ng reschedule'),
        content: TextField(
          controller: reasonCtrl,
          decoration:
              const InputDecoration(hintText: 'Hal. emergency, may exam'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await store.reschedule(r, date, time.format(context), reasonCtrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Na-update ang schedule.')));
    }
  }

  Future<void> _addHours(BuildContext context, CsRecord r) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rendered hours'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Ilang oras ang idadagdag?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final n = double.tryParse(ctrl.text.trim());
    if (ok != true || n == null || n <= 0) return;
    r.hoursRendered += n;
    await store.saveRecord(r);
  }

  Future<void> _confirmDelete(BuildContext context, CsRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('I-delete ang record?'),
        content: Text('${r.ticketNo} ay permanenteng made-delete.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteRecord(r.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
