import 'package:package_info/package_info.dart';

import 'logging.dart';

const String appTitle = 'Amplissimus';
Future<String> get appVersion async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (e) {
    ampErr('AppVersion', e);
    return '0.0.0-1';
  }
}

Future<String> get buildNumber async =>
    (await PackageInfo.fromPlatform()).buildNumber;
