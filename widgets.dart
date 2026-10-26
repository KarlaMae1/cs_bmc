import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';

final DateFormat dateFmt = DateFormat('MMM d, yyyy');

String hoursText(double h) =>
    h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);

Color statusColor(String status) {
  switch (status) {
    case 'Completed':
      return Colors.green;
    case 'Ongoing':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class RecordCard extends StatelessWidget {
  final CsRecord record;
  final String studentName;
  final bool showStudent;
  final VoidCallback onTap;

  const RecordCard({
    super.key,
    required this.record,
    required this.studentName,
    required this.showStudent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(record.ticketNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  StatusChip(record.status),
                ],
              ),
              if (showStudent) ...[
                const SizedBox(height: 4),
                Text(studentName, style: TextStyle(color: cs.primary)),
              ],
              const SizedBox(height: 4),
              Text(record.violation),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: record.progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${hoursText(record.hoursRendered)} / ${hoursText(record.hoursRequired)} hrs',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  Text(
                    record.dutyDate == null
                        ? 'Walang schedule'
                        : 'Duty: ${dateFmt.format(record.dutyDate!)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
