import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location/location_service.dart';
import 'network/api_client.dart';
import 'storage/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenReader: () => ref.read(secureStorageProvider).readToken(),
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
