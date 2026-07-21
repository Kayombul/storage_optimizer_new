# Graph Report - .  (2026-06-18)

## Corpus Check
- Corpus is ~16,608 words - fits in a single context window. You may not need a graph.

## Summary
- 344 nodes · 434 edges · 44 communities (32 shown, 12 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 107 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Windows Flutter Runner|Windows Flutter Runner]]
- [[_COMMUNITY_Cross-Platform Plugin Registry|Cross-Platform Plugin Registry]]
- [[_COMMUNITY_Linux GTK Runner|Linux GTK Runner]]
- [[_COMMUNITY_Linux Build System|Linux Build System]]
- [[_COMMUNITY_Flutter App Entry Points|Flutter App Entry Points]]
- [[_COMMUNITY_iOS Flutter Runtime|iOS Flutter Runtime]]
- [[_COMMUNITY_Win32 Window API|Win32 Window API]]
- [[_COMMUNITY_Android Build and Icons|Android Build and Icons]]
- [[_COMMUNITY_iOS Test Suite|iOS Test Suite]]
- [[_COMMUNITY_macOS Plugin Registration|macOS Plugin Registration]]
- [[_COMMUNITY_Web App Manifest|Web App Manifest]]
- [[_COMMUNITY_iOS App Icons|iOS App Icons]]
- [[_COMMUNITY_Dart Project Config|Dart Project Config]]
- [[_COMMUNITY_iOS Icon Images|iOS Icon Images]]
- [[_COMMUNITY_Dart Project Structure|Dart Project Structure]]
- [[_COMMUNITY_macOS App Icons|macOS App Icons]]
- [[_COMMUNITY_Flutter LLDB Debug Tools|Flutter LLDB Debug Tools]]
- [[_COMMUNITY_Android App Icons|Android App Icons]]
- [[_COMMUNITY_iOS Launch Screen|iOS Launch Screen]]
- [[_COMMUNITY_iOS Scene Lifecycle|iOS Scene Lifecycle]]
- [[_COMMUNITY_PWA Icons|PWA Icons]]
- [[_COMMUNITY_Android Python Integration|Android Python Integration]]
- [[_COMMUNITY_Android Flutter Engine|Android Flutter Engine]]
- [[_COMMUNITY_Win32 FlutterWindow Header|Win32 FlutterWindow Header]]
- [[_COMMUNITY_Graphify Dev Tools|Graphify Dev Tools]]
- [[_COMMUNITY_Windows Plugin Registry|Windows Plugin Registry]]
- [[_COMMUNITY_Android Activity|Android Activity]]
- [[_COMMUNITY_iOS ObjC Plugin Registrant|iOS ObjC Plugin Registrant]]
- [[_COMMUNITY_Web Entrypoint|Web Entrypoint]]
- [[_COMMUNITY_iOS Build Environment|iOS Build Environment]]
- [[_COMMUNITY_macOS Build Environment|macOS Build Environment]]
- [[_COMMUNITY_iOS Swift Package|iOS Swift Package]]
- [[_COMMUNITY_iOS Launch Assets|iOS Launch Assets]]
- [[_COMMUNITY_macOS Swift Package|macOS Swift Package]]
- [[_COMMUNITY_Linux Plugin Call Site|Linux Plugin Call Site]]

## God Nodes (most connected - your core abstractions)
1. `Create()` - 12 edges
2. `MessageHandler()` - 11 edges
3. `WndProc()` - 10 edges
4. `WindowClassRegistrar` - 9 edges
5. `App Icon 1024x1024 @1x` - 9 edges
6. `wWinMain()` - 8 edges
7. `Destroy()` - 8 edges
8. `Windows Runner Executable` - 8 edges
9. `Flutter Default App Icon (Unmodified Branding)` - 8 edges
10. `Flutter Logo Visual Design - Light Blue and Navy Chevron F Shape` - 8 edges

## Surprising Connections (you probably didn't know these)
- `FlutterGeneratedPluginSwiftPackage (macOS Swift)` --semantically_similar_to--> `RegisterPlugins (Windows C++)`  [INFERRED] [semantically similar]
  macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Sources/FlutterGeneratedPluginSwiftPackage/FlutterGeneratedPluginSwiftPackage.swift → windows/flutter/generated_plugin_registrant.cc
- `Linux Generated Plugin Registrant (C++)` --semantically_similar_to--> `macOS Generated Plugin Registrant (Swift)`  [INFERRED] [semantically similar]
  linux/flutter/generated_plugin_registrant.cc → macos/Flutter/GeneratedPluginRegistrant.swift
- `RegisterPlugins Declaration (Windows Header)` --references--> `Flutter Plugin Registry Pattern`  [INFERRED]
  windows/flutter/generated_plugin_registrant.h → ios/Runner/AppDelegate.swift
- `fl_register_plugins() Function` --conceptually_related_to--> `Flutter Plugin Registry Pattern`  [INFERRED]
  linux/flutter/generated_plugin_registrant.cc → ios/Runner/AppDelegate.swift
- `RegisterGeneratedPlugins() Swift Function` --conceptually_related_to--> `Flutter Plugin Registry Pattern`  [INFERRED]
  macos/Flutter/GeneratedPluginRegistrant.swift → ios/Runner/AppDelegate.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Flutter Cross-Platform Build: Linux and Windows CMake Pipelines** — linux_cmakelists_linux_build, windows_cmakelists_windows_build, cross_platform_flutter_build_system, linux_flutter_cmakelists_flutter_library_linux, windows_flutter_cmakelists_flutter_library_win [INFERRED 0.85]
- **flutter_assemble Target Drives Library and Runner Builds** — linux_flutter_cmakelists_flutter_assemble, linux_flutter_cmakelists_flutter_library_linux, linux_runner_cmakelists_linux_runner, linux_cmakelists_linux_build [EXTRACTED 1.00]
- **Windows Runner Links Flutter Library, Wrapper, and DWM API** — windows_runner_cmakelists_windows_runner, windows_flutter_cmakelists_flutter_wrapper_app, windows_flutter_cmakelists_flutter_library_win, windows_runner_cmakelists_dwmapi [EXTRACTED 1.00]
- **Android Launcher Icon Density Variants** — mipmap_mdpi_ic_launcher_app_icon, mipmap_hdpi_ic_launcher_app_icon, mipmap_xhdpi_ic_launcher_app_icon, mipmap_xxhdpi_ic_launcher_app_icon, mipmap_xxxhdpi_ic_launcher_app_icon [INFERRED 0.95]
- **All iOS App Icon Sizes** — appiconset_icon_app_40x40_2x_image, appiconset_icon_app_40x40_3x_image, appiconset_icon_app_60x60_2x_image, appiconset_icon_app_60x60_3x_image, appiconset_icon_app_76x76_1x_image, appiconset_icon_app_76x76_2x_image, appiconset_icon_app_835x835_2x_image [INFERRED 0.95]
- **Flutter Default iOS Assets** — appiconset_icon_app_40x40_2x_image, appiconset_icon_app_40x40_3x_image, appiconset_icon_app_60x60_2x_image, appiconset_icon_app_60x60_3x_image, appiconset_icon_app_76x76_1x_image, appiconset_icon_app_76x76_2x_image, appiconset_icon_app_835x835_2x_image, launchimageset_launchimage_1x_image, launchimageset_launchimage_2x_image, launchimageset_launchimage_3x_image [INFERRED 0.85]
- **All Launch Image Densities** — launchimageset_launchimage_1x_image, launchimageset_launchimage_2x_image, launchimageset_launchimage_3x_image [INFERRED 0.95]
- **macOS App Icon Resolution Set** — macos_appiconset_app_icon_1024_image, macos_appiconset_app_icon_512_image, macos_appiconset_app_icon_256_image, macos_appiconset_app_icon_128_image, macos_appiconset_app_icon_64_image, macos_appiconset_app_icon_32_image, macos_appiconset_app_icon_16_image [INFERRED 0.95]
- **Flutter PWA Icon Set for Storage Optimizer Web App** — web_favicon_app_icon, icons_icon_192_pwa_icon, icons_icon_512_pwa_icon, icons_icon_maskable_192_pwa_icon, icons_icon_maskable_512_pwa_icon [INFERRED 0.95]
- **Maskable PWA Icon Pair (192 and 512)** — icons_icon_maskable_192_pwa_icon, icons_icon_maskable_512_pwa_icon, concept_maskable_icon_spec [INFERRED 0.95]
- **Android Flutter Bridge** — android_main_activity, android_generated_plugin_registrant, concept_flutter_android_embedding [INFERRED 0.85]
- **Flutter App Widget Tree** — lib_main, lib_main_myapp, lib_main_myhomepage, lib_main_myhomepagestate [EXTRACTED 1.00]
- **iOS Runner Plugin Registration System** — runner_appdelegate_class, runner_generatedpluginregistrant_impl, runner_generatedpluginregistrant_header, runner_bridging_header [INFERRED 0.95]
- **Flutter Auto-Generated iOS Artifacts** — flutter_flutter_export_environment_config, runner_generatedpluginregistrant_impl, fluttergeneratedpluginswiftpackage_package, fluttergeneratedpluginswiftpackage_sources_module, ephemeral_flutter_lldb_helper_module [INFERRED 0.85]
- **Cross-platform Flutter Plugin Registry Pattern** — linux_fl_register_plugins_fn, macos_register_generated_plugins_fn, concept_flutter_plugin_registry [INFERRED 0.95]
- **Platform-specific Runner Entry Points** — runner_main_entrypoint, macos_runner_appdelegate, macos_runner_mainflutterwindow, concept_platform_runner [INFERRED 0.90]

## Communities (44 total, 12 thin omitted)

### Community 0 - "Windows Flutter Runner"
Cohesion: 0.10
Nodes (33): Point, RECT, OnCreate(), OnDestroy(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea() (+25 more)

### Community 1 - "Cross-Platform Plugin Registry"
Cohesion: 0.08
Nodes (28): Flutter Plugin Registry Pattern, Platform Runner Entry Point, Flutter Export Environment Config, RegisterPlugins (Windows C++), flutter::PluginRegistry (Windows), RegisterPlugins Declaration (Windows Header), FlutterGeneratedPluginSwiftPackage Package Manifest, FlutterGeneratedPluginSwiftPackage Swift Module (+20 more)

### Community 2 - "Linux GTK Runner"
Cohesion: 0.11
Nodes (22): FlPluginRegistry, fl_register_plugins(), FlView, GApplication, gboolean, gchar, GObject, GtkApplication (+14 more)

### Community 3 - "Linux Build System"
Cohesion: 0.14
Nodes (22): Flutter Cross-Platform Build System, Linux Binary: storage_optimizer_new, GTK+ 3.0 Dependency, Linux CMake Top-Level Build, flutter_assemble Build Target (Linux), Linux Flutter Library (libflutter_linux_gtk.so), GIO 2.0 Dependency, GLib 2.0 Dependency (+14 more)

### Community 4 - "Flutter App Entry Points"
Cohesion: 0.12
Nodes (19): GeneratedPluginRegistrant Java, MainActivity Kotlin, Flutter Android Embedding, build, _counter, createState, _incrementCounter, main (+11 more)

### Community 5 - "iOS Flutter Runtime"
Cohesion: 0.11
Nodes (14): Any, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, Bool, Flutter, AppDelegate, UIKit (+6 more)

### Community 6 - "Win32 Window API"
Cohesion: 0.16
Nodes (14): _In_, _In_opt_, FlutterWindow Class, flutter_window.h Header, wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), utils.h Header (+6 more)

### Community 7 - "Android Build and Icons"
Cohesion: 0.17
Nodes (13): Gradle Wrapper Script (Android), gradle-wrapper.jar Classpath, GradleWrapperMain Entry Point, iOS App Icon Asset Catalog, iPad App Icons Set, iPhone App Icons Set, iOS Marketing App Icon 1024x1024, Flutter Multi-Platform Build System (+5 more)

### Community 8 - "iOS Test Suite"
Cohesion: 0.15
Nodes (9): Flutter, RunnerTests, UIKit, XCTest, Cocoa, FlutterMacOS, RunnerTests, XCTest (+1 more)

### Community 9 - "macOS Plugin Registration"
Cohesion: 0.18
Nodes (8): RegisterGeneratedPlugins(), FlutterPluginRegistry, Foundation, FlutterMacOS, Cocoa, FlutterMacOS, NSWindow, MainFlutterWindow

### Community 10 - "Web App Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 11 - "iOS App Icons"
Cohesion: 0.51
Nodes (10): App Icon 1024x1024 @1x, App Icon 20x20 @1x, App Icon 20x20 @2x, App Icon 20x20 @3x, App Icon 29x29 @1x, App Icon 29x29 @2x, App Icon 29x29 @3x, App Icon 40x40 @1x (+2 more)

### Community 12 - "Dart Project Config"
Cohesion: 0.25
Nodes (9): Dart Analyzer Configuration, flutter_lints Package, cupertino_icons Dependency, flutter_lints Dev Dependency, flutter_test Dev Dependency, Material Design (uses-material-design), pubspec.yaml Package Manifest, Flutter Framework (+1 more)

### Community 13 - "iOS Icon Images"
Cohesion: 0.50
Nodes (9): App Icon 40x40 @2x, App Icon 40x40 @3x, App Icon 60x60 @2x, App Icon 60x60 @3x, App Icon 76x76 @1x, App Icon 76x76 @2x, App Icon 83.5x83.5 @2x, iOS App Icon Set (+1 more)

### Community 14 - "Dart Project Structure"
Cohesion: 0.25
Nodes (8): DartProject, MessageHandler(), HWND, LPARAM, LRESULT, FlutterWindow(), UINT, WPARAM

### Community 15 - "macOS App Icons"
Cohesion: 0.42
Nodes (9): App Icon 1024px, App Icon 128px, App Icon 16px, App Icon 256px, App Icon 32px, App Icon 512px, App Icon 64px, Flutter Logo Branding Concept (+1 more)

### Community 16 - "Flutter LLDB Debug Tools"
Cohesion: 0.36
Nodes (7): NOTIFY_DEBUGGER_ABOUT_RX_PAGES Breakpoint Hook, handle_new_rx_page(), __lldb_init_module(), Flutter LLDB Helper Module, Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 17 - "Android App Icons"
Cohesion: 0.67
Nodes (7): Android Mipmap Launcher Icon Set, Flutter Logo Branding, App Icon (hdpi), App Icon (mdpi), App Icon (xhdpi), App Icon (xxhdpi), App Icon (xxxhdpi)

### Community 18 - "iOS Launch Screen"
Cohesion: 0.70
Nodes (5): Blank Splash Screen Design, iOS Launch Image Set, Launch Image @1x, Launch Image @2x, Launch Image @3x

### Community 19 - "iOS Scene Lifecycle"
Cohesion: 0.40
Nodes (4): FlutterSceneDelegate, Flutter, UIKit, SceneDelegate

### Community 20 - "PWA Icons"
Cohesion: 0.50
Nodes (5): PWA Icon 192x192 (Flutter Logo), PWA Icon 512x512 (Flutter Logo), PWA Maskable Icon 192x192 (Flutter Logo), PWA Maskable Icon 512x512 (Flutter Logo), Web Favicon (Flutter App Icon)

### Community 24 - "Graphify Dev Tools"
Cohesion: 0.67
Nodes (3): Claude Settings Local JSON, Graphify Knowledge Graph Tool, Graphify Install PowerShell Script

### Community 28 - "Web Entrypoint"
Cohesion: 0.67
Nodes (3): flutter_bootstrap.js Web Loader, Web HTML Entry Point (index.html), Web App Manifest (manifest.json)

## Knowledge Gaps
- **109 isolated node(s):** `PackageDescription`, `SBFrame`, `SBDebugger`, `flutter_export_environment.sh script`, `Flutter` (+104 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `wWinMain()` connect `Win32 Window API` to `Windows Flutter Runner`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `Create()` connect `Windows Flutter Runner` to `Win32 Window API`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `AppDelegate Class` connect `Cross-Platform Plugin Registry` to `Flutter LLDB Debug Tools`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `PackageDescription`, `SBFrame`, `SBDebugger` to the rest of the system?**
  _110 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Windows Flutter Runner` be split into smaller, more focused modules?**
  _Cohesion score 0.09581646423751687 - nodes in this community are weakly interconnected._
- **Should `Cross-Platform Plugin Registry` be split into smaller, more focused modules?**
  _Cohesion score 0.082010582010582 - nodes in this community are weakly interconnected._
- **Should `Linux GTK Runner` be split into smaller, more focused modules?**
  _Cohesion score 0.10666666666666667 - nodes in this community are weakly interconnected._