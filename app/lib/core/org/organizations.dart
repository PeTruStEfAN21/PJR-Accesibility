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

  /// Reloads everything; a network error keeps what was loaded before.
  Future<void> refresh() async {
    if (!account.isSignedIn) {
      memberships = const [];
      invites = const [];
      await sounds?.replaceShared(const []);
      notifyListeners();
      return;
    }
    try {
      memberships = await store.myOrganizations();
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
