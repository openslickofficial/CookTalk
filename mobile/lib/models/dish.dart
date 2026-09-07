class Ingredient {
  final String name;
  final String quantity;
  final String unit;

  const Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };
}

class RecipeStep {
  final int step;
  final String instruction;

  const RecipeStep({
    required this.step,
    required this.instruction,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      step: (json['step'] as num?)?.toInt() ?? 1,
      instruction: json['instruction'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'step': step,
        'instruction': instruction,
      };
}

class Dish {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String category;
  final String cuisine;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty;
  final String imageUrl;
  final bool isTrending;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final Map<String, String> substitutions;

  const Dish({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.cuisine,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.imageUrl,
    this.isTrending = false,
    this.ingredients = const [],
    this.steps = const [],
    this.substitutions = const {},
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  factory Dish.fromJson(Map<String, dynamic> json) {
    final ingList = (json['ingredients'] as List<dynamic>?)
            ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final stepsList = (json['steps'] as List<dynamic>?)
            ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final subs = <String, String>{};
    if (json['substitutions'] is Map) {
      (json['substitutions'] as Map).forEach((k, v) {
        subs[k.toString()] = v.toString();
      });
    }

    return Dish(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'lunch',
      cuisine: json['cuisine'] as String? ?? 'Global',
      prepTimeMinutes: (json['prep_time_minutes'] as num?)?.toInt() ?? 10,
      cookTimeMinutes: (json['cook_time_minutes'] as num?)?.toInt() ?? 15,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      imageUrl: json['image_url'] as String? ??
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
      isTrending: json['is_trending'] as bool? ?? false,
      ingredients: ingList,
      steps: stepsList,
      substitutions: subs,
    );
  }
}
