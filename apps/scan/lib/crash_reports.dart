import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crash reports to Sentry, only after the parent turned them on.
///
/// Off by default. Nothing starts without the parent's consent: the
/// Sentry SDK is not even initialised. What is sent: the error type and
/// message, the stack trace, the app version, the device model and OS.
/// Not sent: screenshots, the widget tree, breadcrumbs (taps, screens,
/// network), IP-based user data, names, photos or tasks.
class CrashReports {
  CrashReports._();

  /// The project's DSN, set at build time:
  /// `--dart-define=SENTRY_DSN=https://...ingest.de.sentry.io/...`.
  /// Empty: the switch is not shown and nothing is ever sent.
  static const dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get available => dsn.isNotEmpty;

  static const _pref = 'crash_reports';
  static final on = ValueNotifier<bool>(false);

  /// At app start: resumes reporting if the parent turned it on earlier.
  static Future<void> start(SharedPreferences p) async {
    on.value = available && (p.getBool(_pref) ?? false);
    if (on.value) await _init();
  }

  static Future<void> set(SharedPreferences p, bool value) async {
    await p.setBool(_pref, value);
    if (!available) return;
    on.value = value;
    if (value) {
      await _init();
    } else {
      await Sentry.close();
    }
  }

  static Future<void> _init() async {
    await SentryFlutter.init((o) {
      o
        ..dsn = dsn
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        ..attachThreads = false
        ..tracesSampleRate = 0
        ..enableAutoPerformanceTracing = false
        ..enableUserInteractionBreadcrumbs = false
        ..enableAutoSessionTracking = false
        ..maxBreadcrumbs = 0
        ..environment = kReleaseMode ? 'production' : 'debug'
        ..beforeSend = _scrub;
    });
    // Sentry's own handlers sit on top of ErrorLog's and call them too,
    // so the local log keeps working.
  }

  /// Last guard: no user, no request, no server name, no breadcrumbs.
  static SentryEvent? _scrub(SentryEvent e, Hint _) {
    e.user = null;
    e.request = null;
    e.serverName = null;
    e.breadcrumbs = null;
    return e;
  }
}
