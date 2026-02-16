/// Drop-in `runApp()` replacement with three-layer error catching,
/// deduplication, and beautiful error screens.
library;

export 'src/config.dart';
export 'src/error_entry.dart';
export 'src/error_observer.dart';
export 'src/runner.dart'
    show
        moinsenReportError,
        moinsenRunApp,
        resetGlobalErrorCatcher,
        setupTestErrorCatcher;
