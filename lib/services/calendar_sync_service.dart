import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../models/task.dart';

/// One-way export to Google Calendar.
///
/// Sign-in is optional. The app must remain fully usable signed-out. All
/// network/auth failures are swallowed and logged — they never throw out of
/// this service, mirroring the notification service's best-effort contract.
///
/// Scope: `https://www.googleapis.com/auth/calendar.events` (least privilege).
class CalendarSyncService {
  CalendarSyncService({
    required this.serverClientId,
    this.loadConnectedFlag,
    this.saveConnectedFlag,
  });

  /// Google **web** client ID (public identifier). The Android client is
  /// auto-matched by package + SHA-1; nothing to paste for it. The web
  /// client *secret* never lives in app source — google_sign_in's Android
  /// flow doesn't need it.
  final String serverClientId;

  /// Optional persistence hooks for the "user has previously opted in" flag.
  /// When provided, the lightweight silent-recovery attempt fires on init
  /// only if the flag is true — so a fresh install never auto-prompts.
  final Future<bool> Function()? loadConnectedFlag;
  final Future<void> Function(bool)? saveConnectedFlag;

  static const List<String> _scopes = [gcal.CalendarApi.calendarEventsScope];

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  GoogleSignInAccount? _currentUser;

  /// Current connection state. UI binds to this; main.dart listens to drive
  /// the one-time back-fill when the user newly connects.
  final ValueNotifier<CalendarConnection> connection =
      ValueNotifier<CalendarConnection>(const CalendarConnection.disconnected());

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _signIn.initialize(serverClientId: serverClientId);
      _authSub = _signIn.authenticationEvents.listen(
        _onAuthEvent,
        onError: (Object err, StackTrace st) {
          debugPrint('CalendarSync auth stream error: $err');
        },
      );
      // Only attempt silent recovery if the user previously opted in. On a
      // fresh install we MUST NOT auto-prompt — sign-in is optional.
      final shouldRecover = await loadConnectedFlag?.call() ?? false;
      if (shouldRecover) {
        unawaited(_signIn.attemptLightweightAuthentication());
      }
    } catch (e, st) {
      debugPrint('CalendarSync.init failed: $e\n$st');
    }
  }

  Future<void> _onAuthEvent(GoogleSignInAuthenticationEvent event) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    _currentUser = user;
    if (user == null) {
      connection.value = const CalendarConnection.disconnected();
      return;
    }
    // Sign-in alone doesn't grant scopes — check whether calendar.events is
    // already authorized from a prior session.
    GoogleSignInClientAuthorization? auth;
    try {
      auth = await user.authorizationClient.authorizationForScopes(_scopes);
    } catch (e) {
      debugPrint('CalendarSync authorizationForScopes failed: $e');
    }
    connection.value = CalendarConnection.connected(
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      authorized: auth != null,
    );
  }

  /// User-initiated connect. Runs sign-in if needed, then requests the
  /// calendar.events scope. Idempotent — safe to call when already connected.
  Future<void> connect() async {
    if (!_signIn.supportsAuthenticate()) {
      debugPrint('CalendarSync: authenticate() unsupported on this platform.');
      return;
    }
    try {
      // Always run sign-in to give the user a fresh chance to pick an account.
      final user = await _signIn.authenticate();
      _currentUser = user;
      // Request the calendar.events scope; throws / returns null if denied.
      await user.authorizationClient.authorizeScopes(_scopes);
      connection.value = CalendarConnection.connected(
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        authorized: true,
      );
      unawaited(saveConnectedFlag?.call(true));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('CalendarSync: sign-in canceled by user.');
        return;
      }
      debugPrint('CalendarSync sign-in failed: ${e.code} ${e.description}');
    } catch (e, st) {
      debugPrint('CalendarSync.connect failed: $e\n$st');
    }
  }

  Future<void> disconnect() async {
    try {
      await _signIn.disconnect();
    } catch (e) {
      debugPrint('CalendarSync.disconnect failed: $e');
    }
    _currentUser = null;
    connection.value = const CalendarConnection.disconnected();
    unawaited(saveConnectedFlag?.call(false));
  }

  bool get isAuthorized {
    final c = connection.value;
    return c.isConnected && c.authorized;
  }

  Future<gcal.CalendarApi?> _api() async {
    try {
      final user = _currentUser;
      if (user == null) return null;
      final auth =
          await user.authorizationClient.authorizationForScopes(_scopes);
      if (auth == null) return null;
      final httpClient = auth.authClient(scopes: _scopes);
      return gcal.CalendarApi(httpClient);
    } catch (e, st) {
      debugPrint('CalendarSync._api failed: $e\n$st');
      return null;
    }
  }

  /// Create or patch the event for [task]. Returns the new event id (or the
  /// existing one), or null on failure / not-authorized.
  ///
  /// The app is the source of truth: if the server says the linked event is
  /// gone (404 / 410) OR has been manually deleted (Google returns the event
  /// shape with `status == 'cancelled'` for a while after deletion), re-insert
  /// a fresh event and return its id so Export/Update reliably resurrects it.
  Future<String?> upsertEvent(Task task) async {
    if (!isAuthorized) return null;
    final due = task.effectiveDueAt;
    if (due == null) return null;
    final api = await _api();
    if (api == null) return null;
    final event = _buildEvent(task, due);
    final existing = task.calendarEventId;
    try {
      if (existing == null) {
        final created = await api.events.insert(event, 'primary');
        return created.id;
      }
      try {
        final patched = await api.events.patch(event, 'primary', existing);
        if (patched.status == 'cancelled') {
          final created = await api.events.insert(event, 'primary');
          return created.id;
        }
        return patched.id ?? existing;
      } on gcal.DetailedApiRequestError catch (e) {
        // Event was deleted on the server side — re-create.
        if (e.status == 404 || e.status == 410) {
          final created = await api.events.insert(event, 'primary');
          return created.id;
        }
        rethrow;
      }
    } catch (e, st) {
      debugPrint('CalendarSync.upsertEvent failed: $e\n$st');
      return null;
    }
  }

  /// Definitive existence check for an event we previously created. Used by
  /// the store on resume to clear stale `calendarEventId` links so the UI
  /// reverts to "Export". Best-effort — never throws.
  ///
  /// * `exists`  — `events.get` succeeded AND the event's `status` is not
  ///   `'cancelled'`.
  /// * `gone`    — 404 / 410, or the event came back with `status == 'cancelled'`.
  /// * `unknown` — any other failure (auth, network, quota). Caller MUST treat
  ///   this as "no information" — never wipe the local link on `unknown`,
  ///   otherwise an offline resume would orphan every linked task.
  Future<EventLinkStatus> eventLinkStatus(String eventId) async {
    if (!isAuthorized) return EventLinkStatus.unknown;
    final api = await _api();
    if (api == null) return EventLinkStatus.unknown;
    try {
      final ev = await api.events.get('primary', eventId);
      if (ev.status == 'cancelled') return EventLinkStatus.gone;
      return EventLinkStatus.exists;
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status == 404 || e.status == 410) return EventLinkStatus.gone;
      debugPrint('CalendarSync.eventLinkStatus api error ${e.status}: ${e.message}');
      return EventLinkStatus.unknown;
    } catch (e, st) {
      debugPrint('CalendarSync.eventLinkStatus failed: $e\n$st');
      return EventLinkStatus.unknown;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (!isAuthorized) return;
    final api = await _api();
    if (api == null) return;
    try {
      await api.events.delete('primary', eventId);
    } on gcal.DetailedApiRequestError catch (e) {
      // 404 / 410 are fine — event is already gone.
      if (e.status != 404 && e.status != 410) {
        debugPrint('CalendarSync.deleteEvent api error ${e.status}: ${e.message}');
      }
    } catch (e, st) {
      debugPrint('CalendarSync.deleteEvent failed: $e\n$st');
    }
  }

  gcal.Event _buildEvent(Task task, DateTime start) {
    // Default duration: 30 minutes. Tier-A — we don't store a duration on
    // tasks, and a non-zero block reads as "appointment" on the calendar.
    final end = start.add(const Duration(minutes: 30));
    return gcal.Event(
      summary: task.title,
      description: task.note,
      start: gcal.EventDateTime(
        dateTime: start.toUtc(),
        timeZone: 'UTC',
      ),
      end: gcal.EventDateTime(
        dateTime: end.toUtc(),
        timeZone: 'UTC',
      ),
    );
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
  }
}

/// UI-facing connection snapshot. `authorized` means the calendar.events scope
/// is granted; `isConnected` alone just means there's a Google session.
class CalendarConnection {
  final bool isConnected;
  final bool authorized;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  const CalendarConnection._({
    required this.isConnected,
    required this.authorized,
    this.email,
    this.displayName,
    this.photoUrl,
  });
  const CalendarConnection.disconnected()
      : this._(isConnected: false, authorized: false);
  const CalendarConnection.connected({
    required String email,
    String? displayName,
    String? photoUrl,
    required bool authorized,
  }) : this._(
          isConnected: true,
          authorized: authorized,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
        );
}

enum EventLinkStatus { exists, gone, unknown }
