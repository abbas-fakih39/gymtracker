import 'package:flutter/material.dart';

import '../db/app_database.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    required this.template,
    required this.exerciseCount,
    super.key,
  });

  final WorkoutTemplate template;
  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysLabel = template.dayOfWeek.isEmpty
        ? 'No days assigned'
        : template.dayOfWeek
            .map((d) => _dayNames[d])
            .join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(daysLabel,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(
              '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
              style: TextStyle(fontSize: 13, color: cs.primary),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
