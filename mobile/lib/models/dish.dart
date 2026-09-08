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
      step: (json['step'] as num?)?.toInt() ??
          (json['step_number'] as num?)?.toInt() ??
          1,
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
  final int baseServings;
  final String difficulty;
  final String imageUrl;
  final bool isTrending;
  final bool verified;
  final String source; // "curated" | "ai_generated"
  final String normalizedName;
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
    this.baseServings = 2,
    required this.difficulty,
    required this.imageUrl,
    this.isTrending = false,
    this.verified = false,
    this.source = 'curated',
    this.normalizedName = '',
    this.ingredients = const [],
    this.steps = const [],
    this.substitutions = const {},
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  static String normalize(String input) {
    var s = input.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim().toLowerCase();
    if (s.isEmpty) return '';
    final words = s.split(RegExp(r'\s+'));
    final normalizedWords = <String>[];
    for (final w in words) {
      if (w.length > 3 && w.endsWith('ies')) {
        normalizedWords.add('${w.substring(0, w.length - 3)}y');
      } else if (w.length > 3 &&
          (w.endsWith('ches') ||
              w.endsWith('shes') ||
              w.endsWith('xes') ||
              w.endsWith('zes') ||
              w.endsWith('ses') ||
              w.endsWith('oes'))) {
        normalizedWords.add(w.substring(0, w.length - 2));
      } else if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
        normalizedWords.add(w.substring(0, w.length - 1));
      } else {
        normalizedWords.add(w);
      }
    }
    return normalizedWords.join(' ');
  }

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

    final titleStr = json['title'] as String? ?? json['name'] as String? ?? '';
    final slugStr = json['slug'] as String? ?? json['id']?.toString() ?? '';
    final rawNorm = json['normalized_name'] as String? ?? '';
    final norm = rawNorm.isNotEmpty ? rawNorm : normalize(titleStr.isNotEmpty ? titleStr : slugStr);

    final rawServings = (json['servings'] as num?)?.toInt() ?? 2;
    final baseServ = (json['base_servings'] as num?)?.toInt() ?? rawServings;

    return Dish(
      id: json['id']?.toString() ?? slugStr,
      slug: slugStr,
      title: titleStr,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'lunch',
      cuisine: json['cuisine'] as String? ?? 'Global',
      prepTimeMinutes: (json['prep_time_minutes'] as num?)?.toInt() ?? 10,
      cookTimeMinutes: (json['cook_time_minutes'] as num?)?.toInt() ?? 15,
      servings: rawServings,
      baseServings: baseServ,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      imageUrl: json['image_url'] as String? ??
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
      isTrending: json['is_trending'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      source: json['source'] as String? ?? 'curated',
      normalizedName: norm,
      ingredients: ingList,
      steps: stepsList,
      substitutions: subs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'description': description,
        'category': category,
        'cuisine': cuisine,
        'prep_time_minutes': prepTimeMinutes,
        'cook_time_minutes': cookTimeMinutes,
        'servings': servings,
        'base_servings': baseServings,
        'difficulty': difficulty,
        'image_url': imageUrl,
        'is_trending': isTrending,
        'verified': verified,
        'source': source,
        'normalized_name': normalizedName,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'substitutions': substitutions,
      };
}

class CookHistoryItem {
  final String userId;
  final String dishId;
  final DateTime lastCookedAt;

  const CookHistoryItem({
    required this.userId,
    required this.dishId,
    required this.lastCookedAt,
  });

  factory CookHistoryItem.fromJson(Map<String, dynamic> json) {
    return CookHistoryItem(
      userId: json['user_id'] as String? ?? '',
      dishId: json['dish_id'] as String? ?? '',
      lastCookedAt: json['last_cooked_at'] != null
          ? DateTime.tryParse(json['last_cooked_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'dish_id': dishId,
        'last_cooked_at': lastCookedAt.toIso8601String(),
      };
}
