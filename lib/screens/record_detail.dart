import 'package:flutter/material.dart';

import '../api_client.dart';
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
            body: const Center(child: Text('Record not found.')),
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
                      builder: (_) => RecordFormScreen(existing: r),
                    ),
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
                          Text(
                            'COMMUNITY SERVICE TICKET',
                            style: TextStyle(
                              color: cs.onPrimary.withValues(alpha: 0.8),
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.ticketNo,
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProfileAvatar(
                                name: student?.name ?? 'Unknown',
                                photoUrl: store
                                    .profilePhotoUri(student?.profilePhoto)
                                    ?.toString(),
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  student?.name ?? 'Unknown',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _row('Student no.', student?.studentNo ?? '-'),
                          _row('Violation', r.violation),
                          _row('Issued', dateFmt.format(r.createdAt)),
                          const Divider(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                                ? 'Not scheduled yet'
                                : dateFmt.format(r.dutyDate!),
                          ),
                          _row(
                            'Duty time',
                            r.dutyTime.isEmpty ? '-' : r.dutyTime,
                          ),
                          if (r.note.isNotEmpty)
                            _row('Reschedule note', r.note),
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
                  label: Text(
                    r.dutyDate == null ? 'Schedule duty' : 'Reschedule duty',
                  ),
                ),
              if (isAdmin && r.status != 'Completed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addHours(context, r),
                  icon: const Icon(Icons.more_time),
                  label: const Text('Add rendered hours'),
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
      helpText: 'New duty date',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'New duty time',
    );
    if (time == null || !context.mounted) return;

    final reasonCtrl = TextEditingController(text: r.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reschedule reason'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'For example: emergency, exam',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await store.reschedule(
        r,
        date,
        time.format(context),
        reasonCtrl.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule updated.')));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
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
          decoration: const InputDecoration(
            hintText: 'How many hours would you like to add?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final n = double.tryParse(ctrl.text.trim());
    if (ok != true || n == null || n <= 0) return;
    final previousHours = r.hoursRendered;
    r.hoursRendered += n;
    try {
      await store.saveRecord(r);
    } on ApiException catch (error) {
      r.hoursRendered = previousHours;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, CsRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text('${r.ticketNo} will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await store.deleteRecord(r.id);
        if (context.mounted) Navigator.pop(context);
      } on ApiException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
  }
}
