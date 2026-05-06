import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/feedback_entry.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackRepository = context.read<FeedbackRepository>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Triage')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppPadding.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Share your feedback', style: textTheme.titleMedium),
                  const SizedBox(height: AppPadding.sm),
                  TextFormField(
                    controller: _messageController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What should we improve?',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter feedback first';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppPadding.md),
                  DropdownButtonFormField<FeedbackCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: FeedbackCategory.values
                        .map(
                          (category) => DropdownMenuItem<FeedbackCategory>(
                            value: category,
                            child: Text(_categoryLabel(category)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: AppPadding.md),
                  FilledButton.icon(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() != true) {
                        return;
                      }

                      await feedbackRepository.addEntry(
                        message: _messageController.text,
                        category: _category,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _messageController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback submitted')),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Submit feedback'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<FeedbackEntry>>(
              stream: feedbackRepository.watchAll(),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <FeedbackEntry>[];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No feedback yet. Add your first item above.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppPadding.md),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppPadding.sm),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppPadding.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Chip(
                                  label: Text(_categoryLabel(entry.category)),
                                ),
                                const Spacer(),
                                Text(
                                  _dateLabel(entry.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppPadding.sm),
                            Text(entry.message),
                            const SizedBox(height: AppPadding.sm),
                            DropdownButtonFormField<FeedbackStatus>(
                              initialValue: entry.status,
                              decoration: const InputDecoration(
                                labelText: 'Triage status',
                              ),
                              items: FeedbackStatus.values
                                  .map(
                                    (status) =>
                                        DropdownMenuItem<FeedbackStatus>(
                                          value: status,
                                          child: Text(_statusLabel(status)),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                feedbackRepository.updateStatus(
                                  id: entry.id,
                                  status: value,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(FeedbackCategory category) {
    return switch (category) {
      FeedbackCategory.bug => 'Bug',
      FeedbackCategory.suggestion => 'Suggestion',
      FeedbackCategory.other => 'Other',
    };
  }

  String _statusLabel(FeedbackStatus status) {
    return switch (status) {
      FeedbackStatus.open => 'Open',
      FeedbackStatus.inReview => 'In review',
      FeedbackStatus.resolved => 'Resolved',
    };
  }

  String _dateLabel(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
