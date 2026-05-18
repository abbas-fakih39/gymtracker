import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';
import '../widgets/template_card.dart';
import 'template_form_screen.dart';

// ---------------------------------------------------------------------------
// Screen-local data model + provider
// ---------------------------------------------------------------------------

class _TemplateSummary {
  final WorkoutTemplate template;
  final int exerciseCount;
  const _TemplateSummary(this.template, this.exerciseCount);
}

final _templatesProvider =
    StreamProvider<List<_TemplateSummary>>((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final templates in db.templatesDao.watchAll()) {
    final summaries = <_TemplateSummary>[];
    for (final t in templates) {
      final exs = await db.templatesDao.getExercisesForTemplate(t.id);
      summaries.add(_TemplateSummary(t, exs.length));
    }
    yield summaries;
  }
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_templatesProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const TemplateFormScreen(),
        )),
        child: const Icon(Icons.add),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summaries) => summaries.isEmpty
            ? const Center(
                child: Text(
                  'No templates yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: summaries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = summaries[i];
                  return Dismissible(
                    key: ValueKey(s.template.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                    onDismissed: (_) =>
                        db.templatesDao.deleteTemplate(s.template.id),
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) =>
                            TemplateFormScreen(template: s.template),
                      )),
                      child: TemplateCard(
                        template: s.template,
                        exerciseCount: s.exerciseCount,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
