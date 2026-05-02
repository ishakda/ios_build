import 'package:flutter/material.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_icons.dart';

class AppConstants {
  static const Map<String, String> _frCategoryOverrides = {
    'Electronics': 'Électronique',
    'Smartphones': 'Smartphones',
    'Feature Phones': 'Téléphones classiques',
    'Tablets': 'Tablettes',
    'Laptops': 'Ordinateurs portables',
    'Desktop PCs': 'Ordinateurs de bureau',
    'Monitors': 'Moniteurs',
    'Printers': 'Imprimantes',
    'Computer Accessories': 'Accessoires informatiques',
    'Storage Devices': 'Stockage',
    'Power Banks': 'Batteries externes',
    'Chargers': 'Chargeurs',
    'Cables': 'Câbles',
    'Smart Watches': 'Montres connectées',
    'Headphones': 'Casques',
    'Speakers': 'Haut-parleurs',
    'Cameras': 'Caméras',
    'Gaming Consoles': 'Consoles de jeu',
    'Gaming Accessories': 'Accessoires gaming',
    'TV & Smart TV': 'TV et Smart TV',
    'Projectors': 'Projecteurs',
    'Fashion': 'Mode',
    'Men': 'Hommes',
    'Men - T-Shirts': 'Hommes - T-shirts',
    'Men - Shirts': 'Hommes - Chemises',
    'Men - Jeans': 'Hommes - Jeans',
    'Men - Pants': 'Hommes - Pantalons',
    'Men - Jackets': 'Hommes - Vestes',
    'Men - Shoes': 'Hommes - Chaussures',
    'Men - Sneakers': 'Hommes - Baskets',
    'Men - Watches': 'Hommes - Montres',
    'Men - Bags': 'Hommes - Sacs',
    'Men - Accessories': 'Hommes - Accessoires',
    'Women': 'Femmes',
    'Women - Dresses': 'Femmes - Robes',
    'Women - Tops': 'Femmes - Hauts',
    'Women - Jeans': 'Femmes - Jeans',
    'Women - Skirts': 'Femmes - Jupes',
    'Women - Hijab': 'Femmes - Hijabs',
    'Women - Shoes': 'Femmes - Chaussures',
    'Women - Bags': 'Femmes - Sacs',
    'Women - Jewelry': 'Femmes - Bijoux',
    'Women - Watches': 'Femmes - Montres',
    'Women - Beauty Accessories': 'Femmes - Accessoires beauté',
    'Kids': 'Enfants',
    'Kids - Boys Clothing': 'Enfants - Vêtements garçons',
    'Kids - Girls Clothing': 'Enfants - Vêtements filles',
    'Kids - Shoes': 'Enfants - Chaussures',
    'Kids - School Bags': 'Enfants - Sacs scolaires',
    'Home & Furniture': 'Maison et meubles',
    'Sofas': 'Canapés',
    'Beds': 'Lits',
    'Mattresses': 'Matelas',
    'Tables': 'Tables',
    'Chairs': 'Chaises',
    'Wardrobes': 'Armoires',
    'Kitchen Tools': 'Ustensiles de cuisine',
    'Cookware': 'Batterie de cuisine',
    'Home Decor': 'Décoration maison',
    'Curtains': 'Rideaux',
    'Carpets': 'Tapis',
    'Lighting': 'Éclairage',
    'Storage Boxes': 'Boîtes de rangement',
    'Beauty & Health': 'Beauté et santé',
    'Skincare': 'Soins de la peau',
    'Makeup': 'Maquillage',
    'Perfume': 'Parfum',
    'Hair Care': 'Soins capillaires',
    'Beard Care': 'Soins de la barbe',
    'Personal Care': 'Soins personnels',
    'Vitamins': 'Vitamines',
    'Fitness Products': 'Produits fitness',
    'Massagers': 'Masseurs',
    'Supermarket / Grocery': 'Supermarché / Épicerie',
    'Food': 'Alimentation',
    'Beverages': 'Boissons',
    'Snacks': 'Snacks',
    'Dairy': 'Produits laitiers',
    'Frozen Food': 'Surgelés',
    'Baby Food': 'Alimentation bébé',
    'Cleaning Supplies': 'Produits ménagers',
    'Laundry': 'Lessive',
    'Household Essentials': 'Essentiels maison',
    'Sports & Outdoor': 'Sports et plein air',
    'Gym Equipment': 'Équipement de sport',
    'Football': 'Football',
    'Running': 'Course',
    'Bicycles': 'Vélos',
    'Camping': 'Camping',
    'Swimming': 'Natation',
    'Sports Shoes': 'Chaussures de sport',
    'Sports Wear': 'Vêtements de sport',
    'Automotive': 'Automobile',
    'Car Accessories': 'Accessoires auto',
    'Tires': 'Pneus',
    'Oils': 'Huiles',
    'Car Electronics': 'Électronique auto',
    'Seat Covers': 'Housses de siège',
    'Cleaning Tools': 'Outils de nettoyage',
    'Motorcycle Accessories': 'Accessoires moto',
    'Books & Stationery': 'Livres et papeterie',
    'Books': 'Livres',
    'Islamic Books': 'Livres islamiques',
    'School Supplies': 'Fournitures scolaires',
    'Office Supplies': 'Fournitures de bureau',
    'Notebooks': 'Cahiers',
    'Pens': 'Stylos',
    'Art Supplies': 'Matériel d’art',
    'Baby Products': 'Produits pour bébé',
    'Diapers': 'Couches',
    'Baby Clothes': 'Vêtements bébé',
    'Baby Toys': 'Jouets bébé',
    'Feeding': 'Alimentation',
    'Strollers': 'Poussettes',
    'Baby Care': 'Soins bébé',
    'Toys & Games': 'Jouets et jeux',
    'Educational Toys': 'Jouets éducatifs',
    'Dolls': 'Poupées',
    'Cars': 'Voitures',
    'Board Games': 'Jeux de société',
    'Video Games': 'Jeux vidéo',
    'Outdoor Toys': 'Jouets d’extérieur',
    'Jewelry & Watches': 'Bijoux et montres',
    'Rings': 'Bagues',
    'Necklaces': 'Colliers',
    'Bracelets': 'Bracelets',
    'Earrings': 'Boucles d’oreilles',
    'Men Watches': 'Montres homme',
    'Women Watches': 'Montres femme',
  };

  static final Map<String, List<Map<String, dynamic>>> categoryTree = {
    'Electronics': _buildSubcategories(
      topCategory: 'Electronics',
      icon: AppIcons.categoryElectronics,
      color: const Color(0xFF1976D2),
      names: const [
        'Smartphones',
        'Feature Phones',
        'Tablets',
        'Laptops',
        'Desktop PCs',
        'Monitors',
        'Printers',
        'Computer Accessories',
        'Storage Devices',
        'Power Banks',
        'Chargers',
        'Cables',
        'Smart Watches',
        'Headphones',
        'Speakers',
        'Cameras',
        'Gaming Consoles',
        'Gaming Accessories',
        'TV & Smart TV',
        'Projectors',
      ],
    ),
    'Fashion': _buildSubcategories(
      topCategory: 'Fashion',
      icon: AppIcons.categoryFashion,
      color: const Color(0xFFC2185B),
      names: const [
        'Men',
        'Men - T-Shirts',
        'Men - Shirts',
        'Men - Jeans',
        'Men - Pants',
        'Men - Jackets',
        'Men - Shoes',
        'Men - Sneakers',
        'Men - Watches',
        'Men - Bags',
        'Men - Accessories',
        'Women',
        'Women - Dresses',
        'Women - Tops',
        'Women - Jeans',
        'Women - Skirts',
        'Women - Hijab',
        'Women - Shoes',
        'Women - Bags',
        'Women - Jewelry',
        'Women - Watches',
        'Women - Beauty Accessories',
        'Kids',
        'Kids - Boys Clothing',
        'Kids - Girls Clothing',
        'Kids - Shoes',
        'Kids - School Bags',
      ],
    ),
    'Home & Furniture': _buildSubcategories(
      topCategory: 'Home & Furniture',
      icon: AppIcons.categoryHome,
      color: const Color(0xFF2E7D32),
      names: const [
        'Sofas',
        'Beds',
        'Mattresses',
        'Tables',
        'Chairs',
        'Wardrobes',
        'Kitchen Tools',
        'Cookware',
        'Home Decor',
        'Curtains',
        'Carpets',
        'Lighting',
        'Storage Boxes',
      ],
    ),
    'Beauty & Health': _buildSubcategories(
      topCategory: 'Beauty & Health',
      icon: AppIcons.categoryBeauty,
      color: const Color(0xFFAD1457),
      names: const [
        'Skincare',
        'Makeup',
        'Perfume',
        'Hair Care',
        'Beard Care',
        'Personal Care',
        'Vitamins',
        'Fitness Products',
        'Massagers',
      ],
    ),
    'Supermarket / Grocery': _buildSubcategories(
      topCategory: 'Supermarket / Grocery',
      icon: AppIcons.basket,
      color: const Color(0xFF558B2F),
      names: const [
        'Food',
        'Beverages',
        'Snacks',
        'Dairy',
        'Frozen Food',
        'Baby Food',
        'Cleaning Supplies',
        'Laundry',
        'Household Essentials',
      ],
    ),
    'Sports & Outdoor': _buildSubcategories(
      topCategory: 'Sports & Outdoor',
      icon: AppIcons.categorySports,
      color: const Color(0xFF00838F),
      names: const [
        'Gym Equipment',
        'Football',
        'Running',
        'Bicycles',
        'Camping',
        'Swimming',
        'Sports Shoes',
        'Sports Wear',
      ],
    ),
    'Automotive': _buildSubcategories(
      topCategory: 'Automotive',
      icon: AppIcons.categoryAccessories,
      color: const Color(0xFF455A64),
      names: const [
        'Car Accessories',
        'Tires',
        'Oils',
        'Car Electronics',
        'Seat Covers',
        'Cleaning Tools',
        'Motorcycle Accessories',
      ],
    ),
    'Books & Stationery': _buildSubcategories(
      topCategory: 'Books & Stationery',
      icon: AppIcons.note,
      color: const Color(0xFF6D4C41),
      names: const [
        'Books',
        'Islamic Books',
        'School Supplies',
        'Office Supplies',
        'Notebooks',
        'Pens',
        'Art Supplies',
      ],
    ),
    'Baby Products': _buildSubcategories(
      topCategory: 'Baby Products',
      icon: AppIcons.bagOpen,
      color: const Color(0xFFF57C00),
      names: const [
        'Diapers',
        'Baby Clothes',
        'Baby Toys',
        'Feeding',
        'Strollers',
        'Baby Care',
      ],
    ),
    'Toys & Games': _buildSubcategories(
      topCategory: 'Toys & Games',
      icon: AppIcons.categoryAll,
      color: const Color(0xFF7B1FA2),
      names: const [
        'Educational Toys',
        'Dolls',
        'Cars',
        'Board Games',
        'Video Games',
        'Outdoor Toys',
      ],
    ),
    'Jewelry & Watches': _buildSubcategories(
      topCategory: 'Jewelry & Watches',
      icon: AppIcons.categoryWatch,
      color: const Color(0xFFC49102),
      names: const [
        'Rings',
        'Necklaces',
        'Bracelets',
        'Earrings',
        'Men Watches',
        'Women Watches',
        'Smart Watches',
      ],
    ),
  };

  static List<String> get topCategoryNames => categoryTree.keys.toList();

  static List<String> subcategoriesOf(String topCategory) {
    final subs = categoryTree[topCategory];
    if (subs == null) {
      return const [];
    }
    return subs.map((entry) => entry['name'] as String).toList();
  }

  static String defaultSubcategoryFor(String topCategory) {
    final subs = subcategoriesOf(topCategory);
    if (subs.isEmpty) {
      return topCategory;
    }
    return subs.first;
  }

  static List<Map<String, dynamic>> get categories {
    final result = <Map<String, dynamic>>[];
    for (final entry in categoryTree.entries) {
      result.add({
        'name': entry.key,
        'key': entry.key.toLowerCase().replaceAll(' ', '_'),
        'icon': _iconForTopCategory(entry.key),
        'color': _colorForTopCategory(entry.key),
      });
      result.addAll(entry.value);
    }
    return result;
  }

  static List<String> get categoryNames =>
      categories.map((e) => e['name'] as String).toSet().toList();

  static String getCategoryDisplay(BuildContext context, String name) {
    if (Localizations.localeOf(context).languageCode == 'fr') {
      final override = _frCategoryOverrides[name];
      if (override != null) {
        return override;
      }
    }
    final category = categories.firstWhere(
      (e) => e['name'] == name,
      orElse: () => {'key': name.toLowerCase().replaceAll(' ', '_')},
    );
    final key = category['key'] as String;
    final translated = context.translate(key);
    if (translated == key) {
      return name;
    }
    return translated;
  }

  static bool isTopCategory(String value) {
    return categoryTree.containsKey(value);
  }

  static List<Map<String, dynamic>> _buildSubcategories({
    required String topCategory,
    required IconData icon,
    required Color color,
    required List<String> names,
  }) {
    return names
        .map(
          (name) => {
            'name': name,
            'key': '$topCategory $name'.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]+'),
              '_',
            ),
            'icon': icon,
            'color': color,
          },
        )
        .toList();
  }

  static IconData _iconForTopCategory(String top) {
    switch (top) {
      case 'Electronics':
        return AppIcons.categoryElectronics;
      case 'Fashion':
        return AppIcons.categoryFashion;
      case 'Home & Furniture':
        return AppIcons.categoryHome;
      case 'Beauty & Health':
        return AppIcons.categoryBeauty;
      case 'Supermarket / Grocery':
        return AppIcons.basket;
      case 'Sports & Outdoor':
        return AppIcons.categorySports;
      case 'Automotive':
        return AppIcons.categoryAccessories;
      case 'Books & Stationery':
        return AppIcons.note;
      case 'Baby Products':
        return AppIcons.bagOpen;
      case 'Toys & Games':
        return AppIcons.categoryAll;
      case 'Jewelry & Watches':
        return AppIcons.categoryWatch;
      default:
        return AppIcons.categoryAll;
    }
  }

  static Color _colorForTopCategory(String top) {
    switch (top) {
      case 'Electronics':
        return const Color(0xFF1976D2);
      case 'Fashion':
        return const Color(0xFFC2185B);
      case 'Home & Furniture':
        return const Color(0xFF2E7D32);
      case 'Beauty & Health':
        return const Color(0xFFAD1457);
      case 'Supermarket / Grocery':
        return const Color(0xFF558B2F);
      case 'Sports & Outdoor':
        return const Color(0xFF00838F);
      case 'Automotive':
        return const Color(0xFF455A64);
      case 'Books & Stationery':
        return const Color(0xFF6D4C41);
      case 'Baby Products':
        return const Color(0xFFF57C00);
      case 'Toys & Games':
        return const Color(0xFF7B1FA2);
      case 'Jewelry & Watches':
        return const Color(0xFFC49102);
      default:
        return Colors.blueGrey;
    }
  }
}
