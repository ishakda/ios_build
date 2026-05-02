import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/constants/algeria_communes.dart';
import 'package:untitled1/core/constants/algeria_wilayas.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/shipping/models/carrier_agency.dart';
import 'package:untitled1/core/services/shipping/models/shipping_cost.dart';
import 'package:untitled1/core/services/shipping/shipping_service.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_event.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_state.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';
import 'package:untitled1/injection_container.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _communeController = TextEditingController();

  int _currentStep = 0;
  bool _isPlacingOrder = false;
  bool _isLoadingSavedData = false;
  bool _isLoadingCarrierData = false;
  List<ShippingCost> _shippingCosts = [];
  List<CarrierAgency> _allAgencies = [];
  CarrierAgency? _selectedAgency;

  String _deliveryType = 'home';
  String _selectedWilaya = '16 - Alger';
  String _selectedCarrier = 'elogistia';
  final String _paymentMethod = 'cod';

  final List<Map<String, String>> _carriers = [
    {'id': 'elogistia', 'name': 'Elogistia'},
    {'id': 'yalidine', 'name': 'Yalidine'},
    {'id': 'zrexpress', 'name': 'ZR Express'},
  ];

  List<Map<String, dynamic>> _savedAddresses = const [];
  String? _selectedAddressId;

  String _wilayaCode(String label) =>
      label.split('-').first.trim().padLeft(2, '0');

  List<String> get _communesForSelectedWilaya =>
      algeriaCommunesByWilayaCode[_wilayaCode(_selectedWilaya)] ?? const [];

  @override
  void initState() {
    super.initState();
    _loadSavedCheckoutData();
    _fetchCarrierData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _communeController.dispose();
    super.dispose();
  }

  double get _shippingFee {
    if (_shippingCosts.isEmpty) {
      // Fallback logic
      final code = int.tryParse(_selectedWilaya.split('-').first.trim()) ?? 16;
      const remote = {
        1,
        8,
        11,
        30,
        32,
        33,
        37,
        39,
        47,
        49,
        50,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
      };
      const metro = {9, 16, 31, 35, 42};
      var fee = remote.contains(code)
          ? 1100.0
          : metro.contains(code)
          ? 500.0
          : 700.0;
      if (_deliveryType == 'stopdesk') {
        fee = (fee - 200).clamp(350, 1200).toDouble();
      }
      return fee;
    }

    final selectedId = _selectedWilaya.split('-').first.trim();
    final cost = _shippingCosts.firstWhere(
      (c) =>
          int.tryParse(c.wilayaId).toString() ==
          int.tryParse(selectedId).toString(),
      orElse: () => ShippingCost(
        wilayaLabel: '',
        wilayaId: '',
        homeCost: 700,
        stopdeskCost: 400,
      ),
    );

    return _deliveryType == 'home' ? cost.homeCost : cost.stopdeskCost;
  }

  List<CarrierAgency> get _filteredAgencies {
    final selectedId = _selectedWilaya.split('-').first.trim();
    return _allAgencies.where((a) => a.wilayaId == selectedId).toList();
  }

  Future<void> _fetchCarrierData() async {
    setState(() => _isLoadingCarrierData = true);
    try {
      final data = await sl<ShippingService>().getCarrierData(_selectedCarrier);
      if (mounted) {
        setState(() {
          _shippingCosts = data.shippingCosts;
          _allAgencies = data.agencies;
        });
      }
    } catch (e) {
      debugPrint('Error fetching carrier checkout data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCarrierData = false);
    }
  }

  Future<void> _loadSavedCheckoutData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() => _isLoadingSavedData = true);
    try {
      final uid = authState.user.id;
      final addresses = await SupabaseService.client
          .from(SupabaseTables.addresses)
          .select()
          .eq('userId', uid)
          .order('isDefault', ascending: false)
          .order('updatedAt', ascending: false);
      if (!mounted) return;

      _savedAddresses = List<Map<String, dynamic>>.from(addresses);
      if (_savedAddresses.isNotEmpty) {
        _selectedAddressId = _savedAddresses.first['id']?.toString();
        _applyAddress(_savedAddresses.first);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('checkout_prefill_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSavedData = false);
    }
  }

  void _applyAddress(Map<String, dynamic> address) {
    _addressController.text = (address['address'] ?? '').toString();
    _communeController.text = (address['commune'] ?? '').toString();
    final w = (address['wilaya'] ?? '').toString();
    if (w.isNotEmpty) {
      for (final item in algeriaWilayas) {
        if (item.toLowerCase() == w.toLowerCase() ||
            item.toLowerCase().endsWith(' - ${w.toLowerCase()}')) {
          _selectedWilaya = item;
          break;
        }
      }
    }
    if (!_communesForSelectedWilaya.contains(_communeController.text.trim())) {
      _communeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(title: Text(context.translate('checkout'))),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, cartState) {
          if (cartState.items.isEmpty) {
            return AppEmptyState(
              icon: AppIcons.cart,
              title: context.translate('cart_empty'),
              subtitle: context.translate('add_items_to_start_checkout'),
            );
          }
          final subtotal = cartState.totalPrice;
          final shipping = _shippingFee;
          final total = subtotal + shipping;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppPageIntroCard(
                  title: context.translate('checkout'),
                  trailing: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF0B63F6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: AppSurfaceCard(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CheckoutStepHeader(currentStep: _currentStep),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: KeyedSubtree(
                              key: ValueKey(_currentStep),
                              child: switch (_currentStep) {
                                0 => _buildShippingStep(),
                                1 => _buildPaymentStep(),
                                _ => _buildReviewStep(
                                  subtotal,
                                  shipping,
                                  total,
                                ),
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 320;
                                final primaryButton = SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isPlacingOrder
                                        ? null
                                        : () async {
                                            if (_currentStep < 2) {
                                              if (_currentStep == 0 &&
                                                  !_formKey.currentState!
                                                      .validate()) {
                                                return;
                                              }
                                              setState(() => _currentStep++);
                                            } else {
                                              await _placeOrder(
                                                cartState,
                                                total,
                                              );
                                            }
                                          },
                                    child: Text(
                                      _isPlacingOrder
                                          ? '...'
                                          : _currentStep == 2
                                          ? context.translate('place_order')
                                          : context.translate('continue_btn'),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                                final secondaryButton = SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _isPlacingOrder
                                        ? null
                                        : () {
                                            if (_currentStep > 0) {
                                              setState(() => _currentStep--);
                                            }
                                          },
                                    child: Text(
                                      context.translate('back'),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );

                                if (_currentStep == 0) {
                                  return primaryButton;
                                }

                                if (isCompact) {
                                  return Column(
                                    children: [
                                      primaryButton,
                                      const SizedBox(height: 10),
                                      secondaryButton,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: primaryButton),
                                    const SizedBox(width: 10),
                                    Expanded(child: secondaryButton),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShippingStep() {
    return Column(
      children: [
        if (_isLoadingSavedData) const LinearProgressIndicator(minHeight: 2),
        if (_savedAddresses.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedAddressId,
            decoration: InputDecoration(
              labelText: context.translate('choose_saved_address'),
            ),
            items: _savedAddresses.map((a) {
              final id = a['id']?.toString() ?? '';
              final title = (a['title'] ?? '').toString();
              final line = (a['address'] ?? '').toString();
              return DropdownMenuItem(value: id, child: Text('$title - $line'));
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedAddressId = value);
              final matches = _savedAddresses.where(
                (a) => a['id']?.toString() == value,
              );
              if (matches.isNotEmpty) {
                setState(() => _applyAddress(matches.first));
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _selectedWilaya,
          decoration: InputDecoration(
            labelText: context.translate('wilaya_commune'),
          ),
          items: algeriaWilayas
              .map(
                (w) => DropdownMenuItem(
                  value: w,
                  child: Text(w, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _selectedWilaya = value ?? _selectedWilaya;
            _selectedAgency = null;
            if (!_communesForSelectedWilaya.contains(
              _communeController.text.trim(),
            )) {
              _communeController.clear();
            }
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              _communesForSelectedWilaya.contains(
                _communeController.text.trim(),
              )
              ? _communeController.text.trim()
              : null,
          decoration: InputDecoration(labelText: context.translate('commune')),
          items: _communesForSelectedWilaya
              .map(
                (commune) => DropdownMenuItem(
                  value: commune,
                  child: Text(commune, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _communeController.text = value ?? '';
          }),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? context.translate('field_required')
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: context.translate('detailed_address'),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? context.translate('field_required')
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCarrier,
          decoration: InputDecoration(
            labelText: context.translate('select_carrier'),
            prefixIcon: const Icon(Icons.local_shipping),
          ),
          items: _carriers.map((c) {
            final isAvailable = c['id'] == 'elogistia';
            return DropdownMenuItem(
              value: c['id'],
              enabled: isAvailable,
              child: Text(
                isAvailable ? c['name']! : '${c['name']} (${context.translate('coming_soon')})',
                style: TextStyle(
                  color: isAvailable ? null : Colors.grey,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCarrier = value;
                _selectedAgency = null;
              });
              _fetchCarrierData();
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              selected: _deliveryType == 'home',
              label: Text(context.translate('home_delivery')),
              onSelected: (_) => setState(() => _deliveryType = 'home'),
            ),
            ChoiceChip(
              selected: _deliveryType == 'stopdesk',
              label: Text(context.translate('stop_desk')),
              onSelected: (_) => setState(() => _deliveryType = 'stopdesk'),
            ),
          ],
        ),
        if (_deliveryType == 'stopdesk') ...[
          const SizedBox(height: 12),
          if (_isLoadingCarrierData)
            const LinearProgressIndicator()
          else if (_filteredAgencies.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.translate('no_pickup_points_for_wilaya'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            DropdownButtonFormField<CarrierAgency>(
              key: ValueKey('agency_$_selectedWilaya'),
              initialValue: _selectedAgency,
              decoration: InputDecoration(
                labelText: context.translate('select_agency'),
                hintText: context.translate('choose_pickup_point'),
              ),
              items: _filteredAgencies
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(
                        '${a.name} - ${a.commune}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedAgency = value),
              validator: (value) =>
                  (_deliveryType == 'stopdesk' && value == null)
                  ? context.translate('field_required')
                  : null,
            ),
          if (_deliveryType == 'stopdesk') ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.translate('stop_desk_checkout_hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              selected: true,
              label: Text(context.translate('cod')),
              onSelected: null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.translate('online_payments_disabled_body'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReviewStep(double subtotal, double shipping, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          label: context.translate('subtotal'),
          value: '${subtotal.toStringAsFixed(0)} ${context.translate('dzd')}',
        ),
        _SummaryRow(
          label: context.translate('shipping_fee'),
          value: '${shipping.toStringAsFixed(0)} ${context.translate('dzd')}',
        ),
        _SummaryRow(
          label: context.translate('total_amount'),
          value: '${total.toStringAsFixed(0)} ${context.translate('dzd')}',
          isTotal: true,
        ),
        const SizedBox(height: 12),
        Text(
          '${context.translate('shipping')}: $_selectedWilaya',
          softWrap: true,
        ),
        Text(
          '${context.translate('payment')}: ${_paymentMethod == 'cod' ? context.translate('cod') : context.translate('chargily')}',
          softWrap: true,
        ),
      ],
    );
  }

  Future<void> _placeOrder(CartState cartState, double total) async {
    if (_isPlacingOrder) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('sign_in_required'))),
      );
      return;
    }

    if (_deliveryType == 'stopdesk' && _filteredAgencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('no_pickup_points_for_wilaya')),
        ),
      );
      return;
    }

    if (_deliveryType == 'stopdesk' && _selectedAgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('select_pickup_point_error'))),
      );
      return;
    }

    if (_deliveryType == 'home' && _communeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('field_required'))),
      );
      return;
    }

    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final shortId = timestamp.substring(timestamp.length - 6);
    final orderNumber =
        'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$shortId';

    final order = Order(
      id: 'ORD-${now.millisecondsSinceEpoch}',
      orderNumber: orderNumber,
      items: cartState.items,
      totalAmount: total,
      orderDate: now,
      status: _paymentMethod == 'cod' ? 'Processing' : 'Pending',
      buyerId: authState.user.id,
      sellerIds: cartState.items
          .map((item) => item.product.sellerId)
          .toSet()
          .whereType<String>()
          .toList(),
      shippingFee: _shippingFee,
      deliveryType: _deliveryType,
      paymentMethod: _paymentMethod,
      shippingAddress: {
        'carrier': _selectedCarrier,
        'wilaya': _selectedWilaya,
        'commune': _deliveryType == 'stopdesk'
            ? (_selectedAgency?.commune ?? _communeController.text.trim())
            : _communeController.text.trim(),
        'address': _addressController.text.trim(),
        'buyerName': authState.user.name.trim(),
        'email': authState.user.email.trim(),
        'phoneNumber': authState.user.phoneNumber?.trim(),
        'savedAddressId': _selectedAddressId,
        'agencyId': _selectedAgency?.id,
        'agencyName': _selectedAgency?.name,
      },
    );

    setState(() => _isPlacingOrder = true);
    try {
      await sl<OrderRepository>().placeOrder(order);
      await sl<ShippingService>().createShipment(
        carrierId: _selectedCarrier,
        orderId: order.id,
      );
      if (!mounted) return;
      context.read<CartBloc>().add(ClearCart());
      if (_paymentMethod == 'chargily') {
        try {
          await _startChargilyCheckout(order.id);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context
                    .translate('order_payment_open_failed')
                    .replaceAll('{error}', localizeErrorMessage(context, e)),
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(context.translate('order_confirmed')),
          content: Text(
            _paymentMethod == 'cod'
                ? context.translate('order_placed_msg')
                : context.translate('order_placed_payment_open'),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(context.translate('return_to_home')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizeErrorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  Future<void> _startChargilyCheckout(String orderId) async {
    final invalidResponseMessage = context.translate(
      'invalid_checkout_response',
    );
    final missingUrlMessage = context.translate('missing_checkout_url');
    final invalidUrlMessage = context.translate('invalid_checkout_url');
    final openPaymentFailedMessage = context.translate(
      'open_payment_page_failed',
    );

    final response = await SupabaseService.client.functions.invoke(
      'create-chargily-checkout',
      body: {'orderId': orderId},
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception(invalidResponseMessage);
    }
    final payload = Map<String, dynamic>.from(data);

    final checkoutUrl = payload['checkoutUrl']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception(missingUrlMessage);
    }

    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) {
      throw Exception(invalidUrlMessage);
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception(openPaymentFailedMessage);
    }
  }
}

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.translate('shipping'),
      context.translate('payment'),
      context.translate('review'),
    ];
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (index) {
            final isActive = index == currentStep;
            final isComplete = index < currentStep;
            final color = isActive || isComplete
                ? AppColors.primary
                : theme.colorScheme.outline;

            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index == labels.length - 1 ? 0 : 8,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: isActive || isComplete ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isActive || isComplete
                              ? AppColors.primary
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.7,
                                ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          labels[index],
                          maxLines: isCompact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
