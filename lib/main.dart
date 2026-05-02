import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled1/core/config/supabase_config.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/language_bloc.dart';
import 'package:untitled1/core/services/onesignal_service.dart';
import 'package:untitled1/core/theme/theme_bloc.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/pages/app_session_gate.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart'
    as product_event;
import 'package:untitled1/features/product/presentation/bloc/recently_viewed_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    developer.log('Starting critical initialization...');

    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(UserAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CartItemAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(OrderAdapter());

    SupabaseConfig.ensureConfigured();
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    developer.log('Supabase initialized');

    await di.init();
    developer.log('Service Locator initialized');

    await OneSignalService.initialize();
    developer.log('OneSignal initialization complete');

    await Hive.openBox<CartItem>('cart');
    await Hive.openBox<Product>('wishlist');
    await Hive.openBox<Product>('recently_viewed');
    await Hive.openBox<Order>('orders');
    await Hive.openBox('settings');

    developer.log('Initialization complete');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 56,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Initialization failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => di.sl<ThemeBloc>()),
            BlocProvider(
              create: (context) => di.sl<AuthBloc>()..add(AuthCheckRequested()),
            ),
            BlocProvider(
              create: (context) =>
                  di.sl<ProductBloc>()..add(product_event.FetchProducts()),
            ),
            BlocProvider(create: (context) => di.sl<CartBloc>()),
            BlocProvider(create: (context) => di.sl<WishlistBloc>()),
            BlocProvider(create: (context) => di.sl<RecentlyViewedBloc>()),
            BlocProvider(create: (context) => di.sl<OrderBloc>()),
            BlocProvider(create: (context) => LanguageBloc()),
          ],
          child: BlocBuilder<LanguageBloc, LanguageState>(
            builder: (context, langState) {
              return BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  return MaterialApp(
                    title: 'Sahla',
                    debugShowCheckedModeBanner: false,
                    theme: themeState.themeData,
                    locale: langState.locale,
                    supportedLocales: const [
                      Locale('en'),
                      Locale('ar'),
                      Locale('fr'),
                    ],
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) {
                      final isArabic =
                          Localizations.localeOf(context).languageCode == 'ar';
                      return Directionality(
                        textDirection:
                            isArabic ? TextDirection.rtl : TextDirection.ltr,
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                    home: const AppSessionGate(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
