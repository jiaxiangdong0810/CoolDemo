# AGENT.md

This file gives future agents the local context needed to work safely in this
repo.

## Project Shape

- Root project: Android Gradle project named `CoolDemo`.
- Main host app: `app`.
- Flutter module: `module_flutter`, included from `module_flutter/.android/include_flutter.groovy` as Gradle project `:flutter`.
- Extra native module: `originalModule`, currently a separate Android application module using Jetpack Compose.
- Large vendored/native source lives under `module_flutter/src/llama_native/llama.cpp`; avoid broad searches or edits there unless the task is specifically about llama.cpp.

## Build And Tooling

- Android build files use Kotlin DSL.
- Version catalog: `gradle/libs.versions.toml`.
- Main app uses Java/Kotlin 17, AGP 8.11.1, Kotlin 2.1.10.
- Do not run Gradle commands in Codex for this project. The local environment
  repeatedly hangs or blocks on Gradle wrapper/cache access; instead, ask the
  user to run the relevant Gradle command themselves.
- Flutter module uses Dart SDK `^3.12.0`.
- Main Android build entry points:
  - `./gradlew :app:assembleDebug`
  - `./gradlew :app:testDebugUnitTest`
- Flutter entry points:
  - `cd module_flutter && flutter pub get`
  - `cd module_flutter && flutter analyze`
  - `cd module_flutter && flutter test`

## Hybrid Android/Flutter Architecture

- `MyApplication` calls `FlutterHybrid.init(this)` on app startup.
- `FlutterHybrid` owns a `FlutterEngineGroup`.
- Native opens Flutter through `FlutterHybrid.open(context, FlowConfig(...))`.
- `HybridFlutterActivity` creates a new `FlutterEngine` per Activity instance via `FlutterEngineGroup.createAndRunEngine`.
- Each Flutter Activity receives an initial route from `FlowConfig.initialRoute`.
- Dart reads that initial route from `PlatformDispatcher.instance.defaultRouteName` and wires it into `MaterialApp.initialRoute`.
- Current native entry page is `FeaturesActivity`, which opens:
  - `/model_setup`
  - `/settings`
  - `/agreement`

Important implication: current design isolates Flutter flows by using separate
engines. That keeps Navigator stacks independent, but increases memory use and
means Dart singletons/state are per engine, not globally shared.

## Native/Flutter Communication

- Current structured bridge is Pigeon:
  - Source: `module_flutter/lib/pigeon/api.dart`
  - Dart generated file: `module_flutter/lib/native/generated/api.g.dart`
  - Kotlin generated file: `app/src/main/java/com/example/cooldemo/pigeon/Api.g.kt`
- Native implementations:
  - `app/src/main/java/com/example/cooldemo/native/UserApiImpl.kt`
  - `app/src/main/java/com/example/cooldemo/native/SettingApiImpl.kt`
- `HybridFlutterActivity.onCreate` registers `UserApi` and `SettingApi` against the current engine messenger.
- There is also a legacy `MethodChannel` named `com.example.cooldemo/navigation`; currently it has no implemented methods on Android, while Dart still calls `openNativeSecondPage` from `SecondFlutterPage`.

Be careful: `module_flutter/tool/generate_pigeon.dart` currently references split
Pigeon files that do not exist in the checked-in tree. Before regenerating
Pigeon code, confirm or fix the generator path so it matches `lib/pigeon/api.dart`.

## Routing Notes

- Flutter route table is in `module_flutter/lib/main.dart`.
- Use named initial routes for native-to-Flutter entry.
- Use Flutter `Navigator` for Flutter-to-Flutter transitions inside the same engine.
- For Flutter-to-native transitions, prefer adding a typed Pigeon HostApi or implementing the existing navigation MethodChannel consistently on Android.
- For native-to-existing-Flutter-stack navigation, the current architecture does not expose a shared/cached engine. Add an explicit routing/event mechanism before assuming an existing Flutter stack can be reused.

## Editing Guidelines

- Do not touch generated files by hand unless the task is explicitly about generated output.
- Keep native/Flutter bridge contracts in Pigeon when adding stable app APIs.
- Keep ad hoc MethodChannel usage limited to temporary or very small navigation experiments.
- Avoid unrelated changes under `originalModule` unless the task specifically includes that module.
- Avoid modifying `module_flutter/src/llama_native/llama.cpp` unless needed; it is a large vendored/native subtree.
- The worktree may contain user changes. Inspect before editing and do not revert unrelated files.
