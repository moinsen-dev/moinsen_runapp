/// Drop-in `runApp()` replacement — the universal LLM debug bridge for
/// Flutter. Three-layer error catching, app-level logging, navigation
/// tracking, screenshot capture, and a CLI tool for live LLM-assisted
/// debugging.
library;

export 'src/config.dart';
export 'src/context_generator.dart' show generateContext;
export 'src/error_entry.dart';
export 'src/error_observer.dart';
export 'src/navigator_observer.dart';
export 'src/prompt_generator.dart'
    show generateBugReport, generateEnhancedReport;
export 'src/runner.dart'
    show
        moinsenLog,
        moinsenReportError,
        moinsenRunApp,
        resetGlobalErrorCatcher,
        resetGlobalLogBuffer,
        setupTestErrorCatcher,
        setupTestLogBuffer;
export 'src/screenshot_service.dart' show ScreenshotResult, ScreenshotService;
