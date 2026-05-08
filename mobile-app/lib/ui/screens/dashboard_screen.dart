import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/pantry_item.dart';
import '../../data/models/recommendations.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/api_status_banner.dart';
import '../widgets/leftover_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<DashboardRecommendations> _recommendationsFuture;
  late Future<AuthUserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _fetchRecommendations();
    _profileFuture = _fetchUserProfile();
  }

  Future<DashboardRecommendations> _fetchRecommendations() {
    return context
        .read<RecommendationRepository>()
        .fetchDashboardRecommendations();
  }

  Future<AuthUserProfile?> _fetchUserProfile() {
    debugPrint('Fetching user profile for dashboard');
    return context.read<AuthRepository>().fetchUserProfile();
  }

  void _refreshRecommendations() {
    setState(() {
      _recommendationsFuture = _fetchRecommendations();
    });
  }

  void _refreshUserProfile() {
    setState(() {
      _profileFuture = _fetchUserProfile();
    });
  }

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _navigateFromDrawer(String routeName) {
    Navigator.of(context).pop();
    context.pushNamed(routeName);
  }

  Future<void> _showEditProfileDialog(AuthUserProfile current) async {
    final firstNameController = TextEditingController(
      text: current.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: current.lastName ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: AppPadding.sm),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) {
      firstNameController.dispose();
      lastNameController.dispose();
      return;
    }

    final success = await context.read<AuthRepository>().updateUserProfile(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
    );

    firstNameController.dispose();
    lastNameController.dispose();

    if (!mounted) {
      return;
    }

    if (success) {
      _refreshUserProfile();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      return;
    }

    final error = context.read<AuthRepository>().lastError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Could not update profile.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pantryState = context.watch<PantryBloc>().state;
    final plannerState = context.watch<PlannerBloc>().state;
    final recipes = context.watch<RecipesBloc>().state.recipes;
    final upcomingMeals =
        plannerState.meals
            .where(
              (meal) => !meal.date.isBefore(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<PlannerBloc, PlannerState>(
          listenWhen: (previous, current) => previous.meals != current.meals,
          listener: (context, state) => _refreshRecommendations(),
        ),
        BlocListener<PantryBloc, PantryState>(
          listenWhen: (previous, current) => previous.items != current.items,
          listener: (context, state) => _refreshRecommendations(),
        ),
        BlocListener<RecipesBloc, RecipesState>(
          listenWhen: (previous, current) =>
              previous.recipes != current.recipes,
          listener: (context, state) => _refreshRecommendations(),
        ),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Pantry Pilot'),
          actions: <Widget>[
            FutureBuilder<AuthUserProfile?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final initials = snapshot.data?.initials ?? 'U';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppPadding.sm,
                  ),
                  child: IconButton(
                    onPressed: _openEndDrawer,
                    tooltip: 'Open account menu',
                    icon: CircleAvatar(radius: 14, child: Text(initials)),
                  ),
                );
              },
            ),
          ],
        ),
        endDrawer: Drawer(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                FutureBuilder<AuthUserProfile?>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    return UserAccountsDrawerHeader(
                      margin: EdgeInsets.zero,
                      accountName: Text(
                        profile?.fullName.isNotEmpty == true
                            ? profile!.fullName
                            : 'Pantry Pilot User',
                      ),
                      accountEmail: Text(profile?.email ?? 'Signed in'),
                      currentAccountPicture: CircleAvatar(
                        child: Text(profile?.initials ?? 'U'),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit profile'),
                        onTap: () async {
                          final profile = await _profileFuture;
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          await _showEditProfileDialog(
                            profile ??
                                const AuthUserProfile(
                                  firstName: null,
                                  lastName: null,
                                  email: null,
                                ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.query_stats),
                        title: const Text('KPI dashboard'),
                        onTap: () => _navigateFromDrawer(AppRouter.kpiName),
                      ),
                      ListTile(
                        leading: const Icon(Icons.feedback_outlined),
                        title: const Text('Feedback'),
                        onTap: () =>
                            _navigateFromDrawer(AppRouter.feedbackName),
                      ),
                      ListTile(
                        leading: const Icon(Icons.favorite_outline),
                        title: const Text('Favorites'),
                        onTap: () =>
                            _navigateFromDrawer(AppRouter.favoritesName),
                      ),
                      ListTile(
                        leading: const Icon(Icons.analytics_outlined),
                        title: const Text('Weekly waste summary'),
                        onTap: () =>
                            _navigateFromDrawer(AppRouter.wasteSummaryName),
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Settings'),
                        onTap: () =>
                            _navigateFromDrawer(AppRouter.settingsName),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.read<AuthBloc>().add(const AuthSignOutRequested());
                  },
                ),
                const SizedBox(height: AppPadding.sm),
              ],
            ),
          ),
        ),
        body: FutureBuilder<DashboardRecommendations>(
          future: _recommendationsFuture,
          builder: (context, snapshot) {
            final recommendations =
                snapshot.data ?? DashboardRecommendations.empty;
            final useSoonIdeas = recommendations.useSoon;
            final leftoverIdeas = recommendations.leftovers;

            // Only ingredients belong in the Use Soon Ingredients section.
            final useSoonIngredients = pantryState.useSoonItems
                .where((item) => item.itemKind == PantryItemKind.ingredient)
                .toList(growable: false);

            // All cooked-meal items, sorted by consume-by date.
            final leftoverItems =
                pantryState.items
                    .where((item) => item.itemKind == PantryItemKind.cookedMeal)
                    .toList(growable: false)
                  ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

            return ListView(
              padding: const EdgeInsets.all(AppPadding.md),
              children: <Widget>[
                if (snapshot.hasError)
                  ApiStatusBanner(
                    message: 'Could not refresh meal ideas',
                    onRetry: _refreshRecommendations,
                  ),
                const SizedBox(height: AppPadding.sm),
                if (upcomingMeals.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Upcoming reminders',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppPadding.sm),
                          ...upcomingMeals.take(2).map((meal) {
                            final recipe = _findRecipeById(
                              recipes,
                              meal.recipeId,
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.notifications_none),
                              title: Text(recipe?.title ?? 'Planned meal'),
                              subtitle: Text(
                                '${meal.slot} on ${meal.date.toLocal().toString().split(' ').first}',
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    title: const Text('This week plan progress'),
                    subtitle: Text(
                      '${plannerState.meals.length} meals planned',
                    ),
                    leading: const Icon(Icons.calendar_month),
                  ),
                ),
                const SizedBox(height: AppPadding.sm),
                Card(
                  child: ListTile(
                    title: const Text('Use Soon'),
                    subtitle: Text(
                      '${pantryState.useSoonItems.length} items are about to expire',
                    ),
                    leading: const Icon(Icons.warning_amber_outlined),
                  ),
                ),
                const SizedBox(height: AppPadding.sm),
                Text('Use Soon Ingredients', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (useSoonIngredients.isEmpty)
                  const Text('No urgent ingredients right now.')
                else
                  ...useSoonIngredients.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.quantity} ${item.unit} - ${item.storageLocation}',
                        ),
                        trailing: Text('D-${item.daysUntilExpiry}'),
                      ),
                    ),
                  ),
                const SizedBox(height: AppPadding.md),
                Text('Leftovers', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (leftoverItems.isEmpty)
                  const Text('No cooked meal leftovers logged yet.')
                else
                  ...leftoverItems.map(
                    (item) => LeftoverCard(
                      key: ValueKey(item.id),
                      item: item,
                      onMarkUsed: () => context.read<PantryBloc>().add(
                        PantryItemDeleted(item.id),
                      ),
                      onDiscard: () => context.read<PantryBloc>().add(
                        PantryItemDeleted(item.id),
                      ),
                      onRecipeTap: (recipeId) => context.pushNamed(
                        AppRouter.recipeDetailName,
                        pathParameters: <String, String>{
                          AppRouter.recipeIdParam: recipeId,
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: AppPadding.md),
                Text('Use Soon Meal Ideas', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (useSoonIdeas.isEmpty)
                  const Text(
                    'Add more pantry items to get expiry-aware meal ideas.',
                  )
                else
                  ...useSoonIdeas.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.recipe.title),
                        subtitle: Text(
                          'Use soon: ${item.useSoonIngredients.join(', ')} • ${item.pantryCoverage}% pantry match',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.pushNamed(
                          AppRouter.recipeDetailName,
                          pathParameters: <String, String>{
                            AppRouter.recipeIdParam: item.recipe.id,
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Recipe? _findRecipeById(List<Recipe> recipes, String recipeId) {
    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }
    return null;
  }
}
