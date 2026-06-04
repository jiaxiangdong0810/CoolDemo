import 'package:pigeon/pigeon.dart';

void main() {
  const kotlinPackage = 'com.example.cooldemo.pigeon';
  const kotlinOutDir = '../app/src/main/java/com/example/cooldemo/pigeon';

  final configs = [
    // common types
    PigeonOptions(
      input: 'lib/pigeon/common/types.dart',
      dartOut: 'lib/native/generated/common_types.g.dart',
      kotlinOut: '$kotlinOutDir/CommonTypes.g.kt',
      kotlinOptions: KotlinOptions(package: kotlinPackage),
    ),
    // user api
    PigeonOptions(
      input: 'lib/pigeon/host/user_api.dart',
      dartOut: 'lib/native/generated/user_api.g.dart',
      kotlinOut: '$kotlinOutDir/UserApi.g.kt',
      kotlinOptions: KotlinOptions(package: kotlinPackage),
    ),
    // setting api
    PigeonOptions(
      input: 'lib/pigeon/host/setting_api.dart',
      dartOut: 'lib/native/generated/setting_api.g.dart',
      kotlinOut: '$kotlinOutDir/SettingApi.g.kt',
      kotlinOptions: KotlinOptions(package: kotlinPackage),
    ),
    // event api (flutter api)
    PigeonOptions(
      input: 'lib/pigeon/flutter/event_api.dart',
      dartOut: 'lib/native/generated/event_api.g.dart',
      kotlinOut: '$kotlinOutDir/EventApi.g.kt',
      kotlinOptions: KotlinOptions(package: kotlinPackage),
    ),
  ];

  for (final config in configs) {
    // runPigeon(options: config);
  }
}
