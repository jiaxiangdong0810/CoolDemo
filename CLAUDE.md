# CLAUDE.md

> **项目指令**：本项目不使用 superpowers 技能。不自动调用 brainstorming、writing-plans、test-driven-development、systematic-debugging 等流程。直接按用户指令执行，按需简化处理。

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

Android + Flutter 混合项目，使用 Flutter Engine Group 实现原生与 Flutter 页面跳转。

## 技术栈与版本

- Gradle 8.14 / AGP 8.11.1 / Kotlin 2.1.10
- compileSdk 36 / minSdk 24 / targetSdk 36 / JVM 17
- Flutter SDK ^3.12.0

## 页面跳转架构

**原生 → Flutter**：`FlutterActivity.withCachedEngine()` + `CustomFlutterActivity`
- `MyApplication` 初始化并预热 Flutter Engine
- `FlutterEngineManager` 基于 `FlutterEngineGroup` 管理 Engine 缓存

**Flutter → 原生**：`MethodChannel`（`com.example/cooldemo/navigation`）
- `SecondFlutterPage` 调用 `openNativeSecondPage` 打开 `SecondActivity`

**导航流**：`MainActivity → FirstFragment → CustomFlutterActivity → FirstFlutterPage → SecondFlutterPage → SecondActivity`

## 常用命令

```bash
# Android
./gradlew :app:assembleDebug      # 编译 Debug
./gradlew :app:installDebug       # 安装到设备
./gradlew test                    # 运行单元测试
./gradlew test --tests "类名"      # 运行单个测试
./gradlew connectedAndroidTest    # 运行仪器测试

# Flutter 模块
cd module_flutter && flutter build aar   # 构建 AAR
cd module_flutter && flutter run         # 独立运行
cd module_flutter && flutter analyze     # 代码检查
cd module_flutter && flutter test        # 运行测试
```

## 关键文件

| 文件 | 说明 |
|------|------|
| `settings.gradle.kts` | 通过 `include_flutter.groovy` 引入 Flutter 模块 |
| `app/build.gradle.kts` | Android 应用配置，依赖 `:flutter` |
| `module_flutter/pubspec.yaml` | Flutter 模块依赖与配置 |
| `app/src/main/AndroidManifest.xml` | 声明 `CustomFlutterActivity` 和 `SecondActivity` |
| `gradle/libs.versions.toml` | Android 依赖版本管理 |

## 注意事项

- 使用阿里云 Maven 镜像（`maven.aliyun.com`）
- `ViewBinding` 已启用
- `flutter_boost` 已注释，当前未使用
