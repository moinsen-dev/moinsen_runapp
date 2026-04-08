/// Drop-in `runApp()` replacement — the universal LLM debug bridge for
/// Flutter. Three-layer error catching, app-level logging, navigation
/// tracking, screenshot capture, device info, lifecycle tracking,
/// HTTP monitoring, state inspection, and a CLI tool for live
/// LLM-assisted debugging.
library;

export 'src/config.dart';
export 'src/context_generator.dart' show generateContext;
export 'src/device_info_collector.dart';
export 'src/error_entry.dart';
export 'src/error_observer.dart';
export 'src/http_monitor.dart' show HttpRecord, MoinsenHttpMonitor;
export 'src/interaction/element_tree_finder.dart' show ElementTreeFinder;
export 'src/interaction/interaction_config.dart' show InteractionConfig;
export 'src/interaction/interactive_element.dart'
    show ElementBounds, InteractiveElement;
export 'src/lifecycle_observer.dart';
export 'src/navigator_observer.dart';
export 'src/prompt_generator.dart'
    show generateBugReport, generateEnhancedReport;
export 'src/runner.dart'
    show
        moinsenExposeState,
        moinsenHideState,
        moinsenLog,
        moinsenReportError,
        moinsenRunApp,
        resetGlobalErrorCatcher,
        resetGlobalLogBuffer,
        setupTestErrorCatcher,
        setupTestLogBuffer;
export 'src/screenshot_service.dart' show ScreenshotResult, ScreenshotService;
export 'src/state_registry.dart';
