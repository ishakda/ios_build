import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_smart_image.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/injection_container.dart';
import 'package:uuid/uuid.dart';

class AddProductPage extends StatefulWidget {
  final Product? productToEdit;
  const AddProductPage({super.key, this.productToEdit});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _brandController;
  late final TextEditingController _colorController;
  late final TextEditingController _sizeController;
  final _picker = ImagePicker();

  final List<File> _galleryImages = [];
  final List<File> _detailImages = [];
  final List<String> _existingGalleryUrls = [];
  final List<String> _existingDetailUrls = [];
  final List<String> _colors = [];
  final List<String> _sizes = [];

  late final List<String> _topCategories;
  List<String> _subcategories = const [];
  late String _selectedTopCategory;
  late String _selectedSubCategory;
  bool _isLoading = false;

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    _topCategories = AppConstants.topCategoryNames;

    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name);
    _descriptionController = TextEditingController(text: p?.description);
    _priceController = TextEditingController(text: p?.price.toString());
    _stockController = TextEditingController(text: p?.stock.toString() ?? '1');
    _brandController = TextEditingController(text: p?.brand);
    _colorController = TextEditingController();
    _sizeController = TextEditingController();

    if (p != null) {
      _selectedTopCategory =
          p.parentCategory ?? _resolveTopCategoryFromProduct(p);
      _subcategories = AppConstants.subcategoriesOf(_selectedTopCategory);
      _selectedSubCategory =
          p.subCategory ??
          (p.category.isNotEmpty
              ? p.category
              : AppConstants.defaultSubcategoryFor(_selectedTopCategory));
      if (!_subcategories.contains(_selectedSubCategory)) {
        _selectedSubCategory = AppConstants.defaultSubcategoryFor(
          _selectedTopCategory,
        );
      }
      _colors.addAll(p.availableColors);
      _sizes.addAll(p.availableSizes);
      _existingGalleryUrls.addAll(p.images);
      _existingDetailUrls.addAll(p.detailImageUrls);
    } else {
      _selectedTopCategory = _topCategories.first;
      _subcategories = AppConstants.subcategoriesOf(_selectedTopCategory);
      _selectedSubCategory = AppConstants.defaultSubcategoryFor(
        _selectedTopCategory,
      );
    }
  }

  String _resolveTopCategoryFromProduct(Product product) {
    if (AppConstants.isTopCategory(product.category)) {
      return product.category;
    }
    for (final top in AppConstants.topCategoryNames) {
      final subs = AppConstants.subcategoriesOf(top);
      if (subs.contains(product.category)) {
        return top;
      }
    }
    return AppConstants.topCategoryNames.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _brandController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _pickGalleryImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (!mounted || files.isEmpty) {
      return;
    }
    setState(() {
      _galleryImages.addAll(files.map((file) => File(file.path)));
    });
  }

  Future<void> _pickDetailImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (!mounted || files.isEmpty) {
      return;
    }
    setState(() {
      _detailImages.addAll(files.map((file) => File(file.path)));
    });
  }

  Future<List<String>> _uploadImages(
    List<File> images, {
    required String ownerId,
    required String folder,
  }) async {
    final urls = <String>[];
    for (final image in images) {
      final fileName =
          'products/$ownerId/$folder/${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
      final url = await SupabaseService.uploadPublicFile(
        bucket: SupabaseBuckets.productMedia,
        path: fileName,
        file: image,
        contentType: 'image/jpeg',
      );
      urls.add(url);
    }
    return urls;
  }

  void _addChipValue(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isEmpty || target.contains(value)) {
      controller.clear();
      return;
    }
    setState(() {
      target.add(value);
      controller.clear();
    });
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.translate('field_required');
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final requiredError = _validateRequired(value);
    if (requiredError != null) {
      return requiredError;
    }

    final parsed = double.tryParse(value!.trim());
    if (parsed == null || parsed < 0) {
      return context.translate('valid_non_negative_price');
    }
    return null;
  }

  String? _validateStock(String? value) {
    final requiredError = _validateRequired(value);
    if (requiredError != null) {
      return requiredError;
    }

    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 0) {
      return context.translate('valid_non_negative_stock');
    }
    return null;
  }

  Map<String, dynamic> _categoryMeta(String name) {
    return AppConstants.categories.firstWhere(
      (entry) => entry['name'] == name,
      orElse: () => {'icon': AppIcons.categoryAll, 'color': AppColors.primary},
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_galleryImages.isEmpty && _existingGalleryUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('add_at_least_one_image')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        throw Exception(context.translate('auth_session_expired'));
      }
      if (!authState.user.isSeller) {
        throw Exception(context.translate('seller_only_publish'));
      }
      if (!authState.user.canPublishProducts) {
        throw Exception(
          authState.user.sellerPublishingBlocker ??
              context.translate('seller_publish_blocked'),
        );
      }

      final galleryUrls = await _uploadImages(
        _galleryImages,
        ownerId: authState.user.id,
        folder: 'gallery',
      );
      final detailUrls = _detailImages.isEmpty
          ? <String>[]
          : await _uploadImages(
              _detailImages,
              ownerId: authState.user.id,
              folder: 'detail',
            );

      final finalGallery = [..._existingGalleryUrls, ...galleryUrls];
      final finalDetails = [..._existingDetailUrls, ...detailUrls];

      final product = Product(
        id: _isEditing ? widget.productToEdit!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        imageUrl: finalGallery.first,
        images: finalGallery,
        detailImageUrls: finalDetails,
        rating: widget.productToEdit?.rating ?? 0,
        reviewsCount: widget.productToEdit?.reviewsCount ?? 0,
        category: _selectedSubCategory,
        stock: int.parse(_stockController.text.trim()),
        sellerId: authState.user.id,
        availableColors: List<String>.from(_colors),
        availableSizes: List<String>.from(_sizes),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        parentCategory: _selectedTopCategory,
        subCategory: _selectedSubCategory,
      );

      if (_isEditing) {
        await sl<ProductRepository>().updateProduct(product);
      } else {
        await sl<ProductRepository>().addProduct(product);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? context.translate('product_updated')
                : context.translate('product_published'),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      developer.log('Submit product error: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .translate('unable_save_product')
                .replaceAll('{error}', localizeErrorMessage(context, e)),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppGradientScaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.translate('edit_product')
              : context.translate('add_product'),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 28),
              children: [
                AppPageIntroCard(
                  title: _isEditing
                      ? context.translate('refine_listing')
                      : context.translate('create_strong_listing'),
                  subtitle: context.translate('listing_subtitle'),
                  trailing: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      AppIcons.sparkles,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildImageSection(
                  title: context.translate('product_gallery'),
                  subtitle: context.translate('gallery_subtitle'),
                  images: _galleryImages,
                  existingUrls: _existingGalleryUrls,
                  onAdd: _pickGalleryImages,
                  onRemoveExisting: (url) {
                    setState(() {
                      _existingGalleryUrls.remove(url);
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildImageSection(
                  title: context.translate('poster_detail_images'),
                  subtitle: context.translate('poster_subtitle'),
                  images: _detailImages,
                  existingUrls: _existingDetailUrls,
                  onAdd: _pickDetailImages,
                  onRemoveExisting: (url) {
                    setState(() {
                      _existingDetailUrls.remove(url);
                    });
                  },
                ),
                const SizedBox(height: 16),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: context.translate('product_name'),
                        hint: context.translate('product_name_hint'),
                        icon: AppIcons.buyer,
                      ),
                      const SizedBox(height: 18),
                      _buildCategorySelectors(),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _brandController,
                        label: context.translate('brand'),
                        hint: context.translate('brand_hint'),
                        icon: AppIcons.offer,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceController,
                              label: context.translate('price_dzd'),
                              hint: '0',
                              icon: AppIcons.cash,
                              keyboardType: TextInputType.number,
                              validator: _validatePrice,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildTextField(
                              controller: _stockController,
                              label: context.translate('stock'),
                              hint: '1',
                              icon: AppIcons.orders,
                              keyboardType: TextInputType.number,
                              validator: _validateStock,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _descriptionController,
                        label: context.translate('main_description'),
                        hint: context.translate('description_hint'),
                        icon: AppIcons.note,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.translate('available_colors_label'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('colors_subtitle'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _buildChipEditor(
                        controller: _colorController,
                        hint: context.translate('add_color'),
                        icon: AppIcons.sparkles,
                        values: _colors,
                        onAdd: () => _addChipValue(_colorController, _colors),
                        onRemove: (value) {
                          setState(() {
                            _colors.remove(value);
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.translate('available_sizes_label'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('sizes_subtitle'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _buildChipEditor(
                        controller: _sizeController,
                        hint: context.translate('add_size'),
                        icon: AppIcons.filter,
                        values: _sizes,
                        onAdd: () => _addChipValue(_sizeController, _sizes),
                        onRemove: (value) {
                          setState(() {
                            _sizes.remove(value);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: Text(
                      _isEditing
                          ? context.translate('save_changes')
                          : context.translate('publish_product'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.16),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required String subtitle,
    required List<File> images,
    List<String> existingUrls = const [],
    required VoidCallback onAdd,
    void Function(String)? onRemoveExisting,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          if (images.isNotEmpty || existingUrls.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...existingUrls.map(
                    (url) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AppSmartImage(
                              url: url,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                          PositionedDirectional(
                            end: 6,
                            top: 6,
                            child: InkWell(
                              onTap: () => onRemoveExisting?.call(url),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  AppIcons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...images.asMap().entries.map((entry) {
                    final index = entry.key;
                    final image = entry.value;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              image,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                          PositionedDirectional(
                            end: 6,
                            top: 6,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  images.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  AppIcons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (images.isNotEmpty || existingUrls.isNotEmpty)
            const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(AppIcons.image),
            label: Text(
              (images.isEmpty && existingUrls.isEmpty)
                  ? context.translate('add_images')
                  : context.translate('add_more_images'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
          validator: validator ?? _validateRequired,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final topItems = _topCategories;
    final subItems = _subcategories.isEmpty
        ? [AppConstants.defaultSubcategoryFor(_selectedTopCategory)]
        : _subcategories;
    final topMeta = _categoryMeta(_selectedTopCategory);
    final topColor = (topMeta['color'] as Color?) ?? AppColors.primary;
    final topIcon = (topMeta['icon'] as IconData?) ?? AppIcons.categoryAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: topColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: topColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: topColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(topIcon, color: topColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('category'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context
                          .translate('subcategory_count')
                          .replaceAll(
                            '{category}',
                            AppConstants.getCategoryDisplay(
                              context,
                              _selectedTopCategory,
                            ),
                          )
                          .replaceAll('{count}', '${subItems.length}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 370;
            final topDropdown = DropdownButtonFormField<String>(
              key: ValueKey('top_$_selectedTopCategory'),
              initialValue: _selectedTopCategory,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: InputDecoration(
                labelText: context.translate('main_category'),
                prefixIcon: Icon(topIcon, size: 18),
              ),
              items: topItems.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    AppConstants.getCategoryDisplay(context, category),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedTopCategory = value;
                  _subcategories = AppConstants.subcategoriesOf(value);
                  _selectedSubCategory = AppConstants.defaultSubcategoryFor(
                    value,
                  );
                });
              },
            );

            final selectedSub = subItems.contains(_selectedSubCategory)
                ? _selectedSubCategory
                : subItems.first;
            final subDropdown = DropdownButtonFormField<String>(
              key: ValueKey('sub_${_selectedTopCategory}_$selectedSub'),
              initialValue: selectedSub,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: InputDecoration(
                labelText: context.translate('sub_category'),
                prefixIcon: const Icon(AppIcons.listBullets, size: 18),
              ),
              items: subItems.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    AppConstants.getCategoryDisplay(context, category),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedSubCategory = value;
                });
              },
            );

            if (isCompact) {
              return Column(
                children: [
                  topDropdown,
                  const SizedBox(height: 10),
                  subDropdown,
                  const SizedBox(height: 10),
                  _buildSubcategoryHint(),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: topDropdown),
                    const SizedBox(width: 10),
                    Expanded(child: subDropdown),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSubcategoryHint(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubcategoryHint() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          context
              .translate('selected_category')
              .replaceAll(
                '{category}',
                AppConstants.getCategoryDisplay(context, _selectedSubCategory),
              ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelectors() {
    return _buildCategoryDropdown();
  }

  Widget _buildChipEditor({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required List<String> values,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(icon, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(AppIcons.plus),
              label: Text(context.translate('add')),
            ),
          ],
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: values.map((value) {
              return Chip(label: Text(value), onDeleted: () => onRemove(value));
            }).toList(),
          ),
        ],
      ],
    );
  }
}
