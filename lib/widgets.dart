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
      child: Text(
        status,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      onForegroundImageError: photoUrl == null ? null : (_, _) {},
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  final CsRecord record;
  final String studentName;
  final String? studentPhotoUrl;
  final bool showStudent;
  final VoidCallback onTap;

  const RecordCard({
    super.key,
    required this.record,
    required this.studentName,
    this.studentPhotoUrl,
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
                  ProfileAvatar(
                    name: studentName,
                    photoUrl: studentPhotoUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.ticketNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusChip(record.status),
                ],
              ),
              if (showStudent) ...[
                const SizedBox(height: 8),
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
                        ? 'Not scheduled'
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
