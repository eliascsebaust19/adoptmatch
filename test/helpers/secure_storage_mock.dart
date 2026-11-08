import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:adoptmatch/core/storage/secure_storage_service.dart';
import 'package:adoptmatch/core/services/local_storage_service.dart';

Future<Map<String, String>> installSecureStorageMock() async {
  final data = <String, String>{};
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(data);
  await SecureStorageService.instance.clearSession();
  LocalStorageService.instance.resetForTesting();
  return data;
}
