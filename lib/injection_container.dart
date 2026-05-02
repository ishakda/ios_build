import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:untitled1/core/api/api_client.dart';
import 'package:untitled1/core/services/elogistia/elogistia_service.dart';
import 'package:untitled1/core/services/shipping/shipping_service.dart';
import 'package:untitled1/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:untitled1/features/admin/domain/repositories/admin_repository.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:untitled1/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:untitled1/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_cubit.dart';
import 'package:untitled1/features/product/data/datasources/product_local_data_source.dart';
import 'package:untitled1/features/product/data/datasources/product_remote_data_source.dart';
import 'package:untitled1/features/product/data/repositories/product_repository_impl.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/recently_viewed_bloc.dart';
import 'package:untitled1/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:untitled1/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:untitled1/features/chat/domain/repositories/chat_repository.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_bloc.dart';
import 'package:untitled1/features/checkout/data/datasources/order_remote_data_source.dart';
import 'package:untitled1/features/checkout/data/repositories/order_repository_impl.dart';
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:untitled1/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:untitled1/features/notifications/domain/repositories/notification_repository.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:untitled1/features/vendor/data/repositories/vendor_repository_impl.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_cubit.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_cubit.dart';
import 'package:untitled1/core/theme/theme_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Core & External
  if (!sl.isRegistered<Dio>()) {
    sl.registerLazySingleton(() => Dio());
  }
  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton(() => ApiClient());
  }

  if (!sl.isRegistered<ElogistiaService>()) {
    sl.registerLazySingleton(() => ElogistiaService());
  }

  if (!sl.isRegistered<ShippingService>()) {
    sl.registerLazySingleton(() => ShippingService());
  }

  //! Features - Auth
  if (!sl.isRegistered<AuthRemoteDataSource>()) {
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(apiClient: sl()),
    );
  }

  //! Features - Admin
  if (!sl.isRegistered<AdminRepository>()) {
    sl.registerLazySingleton<AdminRepository>(() => AdminRepositoryImpl());
  }
  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl()),
    );
  }

  //! Features - Product
  if (!sl.isRegistered<ProductRemoteDataSource>()) {
    sl.registerLazySingleton<ProductRemoteDataSource>(
      () => ProductRemoteDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<ProductLocalDataSource>()) {
    sl.registerLazySingleton<ProductLocalDataSource>(
      () => ProductLocalDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<ProductRepository>()) {
    sl.registerLazySingleton<ProductRepository>(
      () =>
          ProductRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    );
  }

  //! Features - Chat
  if (!sl.isRegistered<ChatRemoteDataSource>()) {
    sl.registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<ChatRepository>()) {
    sl.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(remoteDataSource: sl()),
    );
  }

  //! Features - Notifications
  if (!sl.isRegistered<NotificationRemoteDataSource>()) {
    sl.registerLazySingleton<NotificationRemoteDataSource>(
      () => NotificationRemoteDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<NotificationRepository>()) {
    sl.registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(remoteDataSource: sl()),
    );
  }

  //! Features - Vendor
  if (!sl.isRegistered<VendorRepository>()) {
    sl.registerLazySingleton<VendorRepository>(() => VendorRepositoryImpl());
  }

  //! Features - Checkout
  if (!sl.isRegistered<OrderRemoteDataSource>()) {
    sl.registerLazySingleton<OrderRemoteDataSource>(
      () => OrderRemoteDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<OrderRepository>()) {
    sl.registerLazySingleton<OrderRepository>(
      () => OrderRepositoryImpl(remoteDataSource: sl()),
    );
  }

  //! BLoCs
  sl.registerFactory(() => ThemeBloc());
  sl.registerFactory(() => ProductBloc(productRepository: sl()));
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  sl.registerFactory(() => AdminUsersCubit(adminRepository: sl()));
  sl.registerFactory(() => UserSearchCubit(authRepository: sl()));
  sl.registerFactory(() => ProfileUpdateCubit(authRepository: sl()));
  sl.registerFactory(() => CartBloc());
  sl.registerFactory(() => WishlistBloc());
  sl.registerFactory(() => RecentlyViewedBloc());
  sl.registerFactory(() => OrderBloc(orderRepository: sl()));
  sl.registerFactory(() => ChatListBloc(chatRepository: sl()));
  sl.registerFactory(() => NotificationsBloc(notificationRepository: sl()));
  sl.registerFactory(() => VendorStoreCubit(vendorRepository: sl()));
  sl.registerFactory(() => VendorOrdersCubit(vendorRepository: sl()));
}
