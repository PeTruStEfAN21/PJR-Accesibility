import 'package:flutter/foundation.dart';

import '../../features/alerts/location_sounds.dart';
import '../../features/alerts/sound_alert.dart';
import '../account/account_service.dart';
import 'org_store.dart';

/// The signed-in user's companies, kept up to date across sign-in and sign-out.
/// Brings the sounds the companies shared (for this device's model) into the
/// sound detector's list.
class Organizations extends ChangeNotifier {
  Organizations({required this.store, required this.account, this.sounds, required this.model}) {
    account.addListener(refresh);
  }

  final OrgStore store;
  final AccountService account;
  final LocationSoundStore? sounds;
  final SoundModel model;

  List<OrgMembership> memberships = const [];
  List<OrgInvite> invites = const [];

  bool get any => memberships.isNotEmpty;

  bool get isAdminAnywhere => memberships.any((m) => m.isAdmin);

  /// How an employee (not an admin) takes part, which picks the phone's tabs; null for an admin or
  /// someone in no company, who keep them all (for now). Reading wins over hearing across companies.
  MemberExperience? get employeeExperience {
    if (memberships.isEmpty || memberships.any((m) => m.isAdmin)) return null;
    return memberships.any((m) => m.experience == MemberExperience.visual)
        ? MemberExperience.visual
        : MemberExperience.standard;
  }

  /// Colleague emergencies go to those who read what is said; hearing colleagues and admins send them.
  /// Someone in no company keeps receiving them, as before.
  bool get receivesColleagueAlarms =>
      memberships.isEmpty || memberships.any((m) => m.experience == MemberExperience.visual);

  Future<void>? _loading;

  /// Whose companies were loaded last (null: nobody yet, or signed out).
  String? _loadedFor;

  /// Reloads everything, after any load already running (something changed, so it must be fresh);
  /// a network error keeps what was loaded before.
  Future<void> refresh() {
    final next = (_loading ?? Future<void>.value()).then((_) => _refresh(), onError: (Object _) => _refresh());
    _loading = next;
    void done() {
      if (identical(_loading, next)) _loading = null;
    }
    next.then((_) => done(), onError: (Object _) => done());
    return next;
  }

  /// The companies loaded at least once for whoever is signed in: waits for the load already running
  /// (signing in starts one) instead of asking the server a second time.
  Future<void> whenLoaded() =>
      _loading ?? (_loadedFor == account.user?.id && _loadedFor != null ? Future<void>.value() : refresh());

  Future<void> _refresh() async {
    if (!account.isSignedIn) {
      memberships = const [];
      invites = const [];
      _loadedFor = null;
      await sounds?.replaceShared(const []);
      notifyListeners();
      return;
    }
    try {
      memberships = await store.myOrganizations();
      _loadedFor = account.user?.id;
      invites = await store.myInvites();
      if (sounds != null) {
        await sounds!.replaceShared([
          for (final m in memberships) ...await store.sharedSounds(m.orgId, model),
        ]);
      }
    } catch (e) {
      debugPrint('Organizations not refreshed: $e');
    }
    notifyListeners();
  }

  /// "I'm safe" / "I need help" during a critical alarm, sent to every company of the user.
  Future<void> answerAlarm(SoundKind kind, AlarmAnswerStatus status) async {
    final userId = account.user?.id;
    if (userId == null) return;
    for (final m in memberships) {
      final event = await store.reportAlarm(m.orgId, kind);
      await store.answerAlarm(m.orgId, event, userId, status);
    }
  }

  @override
  void dispose() {
    account.removeListener(refresh);
    super.dispose();
  }
}
