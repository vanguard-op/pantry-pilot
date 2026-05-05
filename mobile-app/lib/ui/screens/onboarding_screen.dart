import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/onboarding/onboarding_bloc.dart';
import '../../navigation/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dietaryController = TextEditingController();
  int _householdSize = 2;
  String _skillLevel = 'Beginner';

  static const staples = <String>[
    'Rice',
    'Pasta',
    'Eggs',
    'Milk',
    'Onion',
    'Garlic',
    'Tomato',
    'Olive Oil',
    'Salt',
    'Beans',
  ];

  final Set<String> _selectedStaples = <String>{};

  @override
  void dispose() {
    _dietaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OnboardingBloc>().state;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listenWhen: (previous, current) => !previous.completed && current.completed,
      listener: (context, state) => context.goNamed(AppRouter.homeName),
      child: Scaffold(
        appBar: AppBar(title: const Text('Welcome to PantryPilot')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Set up your kitchen profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Household size'),
              Slider(
                value: _householdSize.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: _householdSize.toString(),
                onChanged: (value) {
                  setState(() => _householdSize = value.round());
                },
              ),
              Text('$_householdSize people'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _skillLevel,
                decoration: const InputDecoration(labelText: 'Cooking skill level'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'Confident', child: Text('Confident')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _skillLevel = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dietaryController,
                decoration: const InputDecoration(
                  labelText: 'Dietary preferences (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick pantry seed checklist',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...staples.map(
                (staple) => CheckboxListTile(
                  value: _selectedStaples.contains(staple),
                  title: Text(staple),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedStaples.add(staple);
                      } else {
                        _selectedStaples.remove(staple);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: state.status == OnboardingStatus.saving
                    ? null
                    : () {
                        context.read<OnboardingBloc>().add(
                              OnboardingSubmitted(
                                householdSize: _householdSize,
                                skillLevel: _skillLevel,
                                dietaryNotes: _dietaryController.text.trim(),
                                staples: _selectedStaples.toList(growable: false),
                              ),
                            );
                      },
                child: Text(
                  state.status == OnboardingStatus.saving ? 'Saving...' : 'Finish setup',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
