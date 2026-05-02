import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  RangeValues _priceRange = const RangeValues(0, 5000000);
  double _minRating = 0;
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', ...AppConstants.categoryNames];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('filter_results'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.translate('price_range'),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 5000000,
            divisions: 100,
            activeColor: AppColors.primary,
            labels: RangeLabels(
              '${_priceRange.start.round()} DZD',
              '${_priceRange.end.round()} DZD',
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const SizedBox(height: 24),
          Text(
            context.translate('category'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) =>
                        setState(() => _selectedCategory = category),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.translate('rating_any'),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _minRating,
            min: 0,
            max: 5,
            divisions: 5,
            activeColor: Colors.amber,
            label: _minRating.round().toString(),
            onChanged: (value) => setState(() => _minRating = value),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                context.read<ProductBloc>().add(
                  FilterProducts(
                    minPrice: _priceRange.start,
                    maxPrice: _priceRange.end,
                    category: _selectedCategory,
                    minRating: _minRating,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.translate('apply_filters'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
