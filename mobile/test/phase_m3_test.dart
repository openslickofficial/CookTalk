import 'package:flutter_test/flutter_test.dart';
import 'package:cooktalk_mobile/models/dish.dart';
import 'package:cooktalk_mobile/services/supabase_service.dart';

void main() {
  group('Phase M3.1 Model & Logic Tests', () {
    test('Dish.normalize handles plurals and casing correctly', () {
      expect(Dish.normalize('Pancakes'), 'pancake');
      expect(Dish.normalize('  BERRIES  '), 'berry');
      expect(Dish.normalize('Soft-Curd Scrambled Eggs!'), 'soft curd scrambled egg');
      expect(Dish.normalize('paneer'), 'paneer');
      expect(Dish.normalize('paneers'), 'paneer');
    });

    test('Dish serialization preserves verified flag and source', () {
      const dish = Dish(
        id: 'test-dish',
        slug: 'test-dish',
        title: 'Test Dish',
        description: 'Testing description',
        category: 'dinner',
        cuisine: 'Global',
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: 4,
        baseServings: 4,
        difficulty: 'Easy',
        imageUrl: 'https://example.com/img.jpg',
        verified: false,
        source: 'ai_generated',
        normalizedName: 'test dish',
      );

      final json = dish.toJson();
      expect(json['verified'], false);
      expect(json['source'], 'ai_generated');
      expect(json['base_servings'], 4);
      expect(json['normalized_name'], 'test dish');

      final deserialized = Dish.fromJson(json);
      expect(deserialized.verified, false);
      expect(deserialized.source, 'ai_generated');
      expect(deserialized.baseServings, 4);
      expect(deserialized.normalizedName, 'test dish');
    });

    test('cook_history tracks per-user cooking history correctly', () async {
      final service = SupabaseService.instance;
      const dishId = 'paneer-butter-masala-test';

      // Initially not cooked
      expect(service.hasCookedBefore(dishId), false);

      // Record cook history
      await service.recordCookHistory(dishId);

      // Now cooked
      expect(service.hasCookedBefore(dishId), true);
    });

    test('Benchmark dishes have verified == true in seed catalog', () async {
      final dishes = await SupabaseService.instance.fetchDishes();
      final scrambled = dishes.firstWhere((d) => d.id == 'scrambled_eggs');
      final cacio = dishes.firstWhere((d) => d.id == 'cacio_e_pepe');
      final ribeye = dishes.firstWhere((d) => d.id == 'ribeye_steak');

      expect(scrambled.verified, true);
      expect(cacio.verified, true);
      expect(ribeye.verified, true);

      // Non-benchmark dishes must be verified == false
      final pancakes = dishes.firstWhere((d) => d.id == 'pancakes');
      expect(pancakes.verified, false);
    });
  });
}
