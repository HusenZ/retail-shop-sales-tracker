import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RetailShopApp(dependencies: AppDependencies(apiBaseUrl: AppConfig.apiBaseUrl)));
}
