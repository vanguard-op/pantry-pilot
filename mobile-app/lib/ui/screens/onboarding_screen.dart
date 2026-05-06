import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/onboarding/onboarding_bloc.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dietaryController = TextEditingController();

  _OnboardingStep _step = _OnboardingStep.welcome;
  _AccountMode _accountMode = _AccountMode.guest;
  int _householdSize = 2;
  String _skillLevel = 'Beginner';
  bool _nudgeToPlanner = true;

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
    _emailController.dispose();
    _passwordController.dispose();
    _dietaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OnboardingBloc>().state;
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listenWhen: (previous, current) =>
          !previous.completed && current.completed,
      listener: (context, state) {
        if (_nudgeToPlanner) {
          context.goNamed(AppRouter.plannerName);
          return;
        }
        context.goNamed(AppRouter.homeName);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to PantryPilot'),
          actions: <Widget>[
            if (_step != _OnboardingStep.welcome)
              TextButton(
                onPressed: state.status == OnboardingStatus.saving
                    ? null
                    : () => _handleBackStep(),
                child: const Text('Back'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppPadding.md),
            children: _buildStepContent(context, textTheme, state),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStepContent(
    BuildContext context,
    TextTheme textTheme,
    OnboardingState state,
  ) {
    final progress = switch (_step) {
      _OnboardingStep.welcome => 0.25,
      _OnboardingStep.account => 0.5,
      _OnboardingStep.profile => 0.75,
      _OnboardingStep.pantrySeed => 1.0,
    };

    return <Widget>[
      LinearProgressIndicator(value: progress),
      const SizedBox(height: AppPadding.md),
      ...switch (_step) {
        _OnboardingStep.welcome => _buildWelcomeStep(textTheme),
        _OnboardingStep.account => _buildAccountStep(textTheme),
        _OnboardingStep.profile => _buildProfileStep(textTheme),
        _OnboardingStep.pantrySeed => _buildPantrySeedStep(textTheme, state),
      },
    ];
  }

  List<Widget> _buildWelcomeStep(TextTheme textTheme) {
    return <Widget>[
      Text('Run your kitchen smarter', style: textTheme.headlineMedium),
      const SizedBox(height: AppPadding.sm),
      Text(
        'PantryPilot keeps inventory, plans meals, and guided cooking in one flow so you waste less and decide faster.',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: AppPadding.md),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.schedule_outlined),
        title: Text('Plan meals in minutes'),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.kitchen_outlined),
        title: Text('Track pantry and use-soon items'),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.soup_kitchen_outlined),
        title: Text('Cook with step-by-step guidance'),
      ),
      const SizedBox(height: AppPadding.lg),
      FilledButton(
        onPressed: () => setState(() => _step = _OnboardingStep.account),
        child: const Text('Get started'),
      ),
    ];
  }

  List<Widget> _buildAccountStep(TextTheme textTheme) {
    return <Widget>[
      Text('Account setup', style: textTheme.headlineMedium),
      const SizedBox(height: AppPadding.sm),
      Text(
        'Choose how you want to continue. You can always update this later.',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: AppPadding.md),
      SegmentedButton<_AccountMode>(
        segments: const <ButtonSegment<_AccountMode>>[
          ButtonSegment<_AccountMode>(
            value: _AccountMode.guest,
            label: Text('Guest'),
            icon: Icon(Icons.person_outline),
          ),
          ButtonSegment<_AccountMode>(
            value: _AccountMode.email,
            label: Text('Email'),
            icon: Icon(Icons.email_outlined),
          ),
          ButtonSegment<_AccountMode>(
            value: _AccountMode.social,
            label: Text('Social'),
            icon: Icon(Icons.login),
          ),
        ],
        selected: <_AccountMode>{_accountMode},
        onSelectionChanged: (selection) {
          setState(() => _accountMode = selection.first);
        },
      ),
      const SizedBox(height: AppPadding.md),
      if (_accountMode == _AccountMode.email) ...<Widget>[
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: AppPadding.sm),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ] else if (_accountMode == _AccountMode.social) ...<Widget>[
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppPadding.md),
            child: Text(
              'Social sign-in providers will be connected in a post-MVP auth pass. Continue to personalize your household now.',
              style: textTheme.bodyMedium,
            ),
          ),
        ),
      ],
      const SizedBox(height: AppPadding.lg),
      FilledButton(
        onPressed: () => setState(() => _step = _OnboardingStep.profile),
        child: Text(
          _accountMode == _AccountMode.guest ? 'Continue as guest' : 'Continue',
        ),
      ),
    ];
  }

  List<Widget> _buildProfileStep(TextTheme textTheme) {
    return <Widget>[
      Text('Household profile', style: textTheme.headlineMedium),
      const SizedBox(height: AppPadding.sm),
      Text(
        'This helps tailor recipe recommendations and planning defaults.',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: AppPadding.md),
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
      const SizedBox(height: AppPadding.md),
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
      const SizedBox(height: AppPadding.md),
      TextFormField(
        controller: _dietaryController,
        decoration: const InputDecoration(
          labelText: 'Dietary preferences (optional)',
        ),
        maxLines: 2,
      ),
      const SizedBox(height: AppPadding.lg),
      FilledButton(
        onPressed: () => setState(() => _step = _OnboardingStep.pantrySeed),
        child: const Text('Next'),
      ),
    ];
  }

  List<Widget> _buildPantrySeedStep(
    TextTheme textTheme,
    OnboardingState state,
  ) {
    return <Widget>[
      Text('Pantry seed', style: textTheme.headlineMedium),
      const SizedBox(height: AppPadding.sm),
      Text(
        'Pick common staples so your first recommendations are useful from day one.',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: AppPadding.md),
      Text('Quick pantry seed checklist', style: textTheme.titleMedium),
      const SizedBox(height: AppPadding.sm),
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
      const SizedBox(height: AppPadding.sm),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _nudgeToPlanner,
        onChanged: (value) => setState(() => _nudgeToPlanner = value),
        title: const Text('Plan my first week right away'),
        subtitle: const Text('Go to weekly planner after setup.'),
      ),
      const SizedBox(height: AppPadding.lg),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: state.status == OnboardingStatus.saving
                  ? null
                  : _submitOnboardingWithoutStaples,
              child: const Text('Skip for now'),
            ),
          ),
          const SizedBox(width: AppPadding.sm),
          Expanded(
            child: FilledButton(
              onPressed: state.status == OnboardingStatus.saving
                  ? null
                  : _submitOnboarding,
              child: Text(
                state.status == OnboardingStatus.saving
                    ? 'Saving...'
                    : 'Finish setup',
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _handleBackStep() {
    setState(() {
      _step = switch (_step) {
        _OnboardingStep.welcome => _OnboardingStep.welcome,
        _OnboardingStep.account => _OnboardingStep.welcome,
        _OnboardingStep.profile => _OnboardingStep.account,
        _OnboardingStep.pantrySeed => _OnboardingStep.profile,
      };
    });
  }

  void _submitOnboardingWithoutStaples() {
    context.read<OnboardingBloc>().add(
      OnboardingSubmitted(
        householdSize: _householdSize,
        skillLevel: _skillLevel,
        dietaryNotes: _dietaryController.text.trim(),
        staples: const <String>[],
      ),
    );
  }

  void _submitOnboarding() {
    context.read<OnboardingBloc>().add(
      OnboardingSubmitted(
        householdSize: _householdSize,
        skillLevel: _skillLevel,
        dietaryNotes: _dietaryController.text.trim(),
        staples: _selectedStaples.toList(growable: false),
      ),
    );
  }
}

enum _OnboardingStep { welcome, account, profile, pantrySeed }

enum _AccountMode { guest, email, social }
