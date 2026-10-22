import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/org/organizations.dart';
import 'package:pjr_accesibilitate/features/alerts/location_sounds.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/alerts/yamnet_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  late FakeAccountService account;
  late FakeOrgStore store;
  late LocationSoundStore sounds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sounds = LocationSoundStore(await SharedPreferences.getInstance());
    account = FakeAccountService();
    store = FakeOrgStore(account);
  });

  Organizations create() => Organizations(store: store, account: account, sounds: sounds, model: SoundModel.tflite);

  LocationSound sound(String label) =>
      LocationSound(id: label, label: label, level: AlertLevel.critical, print: normalized([1, 2]));

  test('signing in loads the companies, invitations and the shared sounds of this device', () async {
    final org = store.addOrg('Fabrica');
    store.addMember(org, 'u-ana@firma.ro');
    store.sounds[org] = [(sound('Alarma halei'), SoundModel.tflite), (sound('Din browser'), SoundModel.tfjs)];
    final other = store.addOrg('Depozit');
    store.invites['i1'] = (orgId: other, email: 'ana@firma.ro', role: OrgRole.employee, department: null);

    final orgs = create();
    account.signInAs('ana@firma.ro');
    await orgs.refresh();

    expect(orgs.memberships.single.orgName, 'Fabrica');
    expect(orgs.invites.single.orgName, 'Depozit');
    expect(sounds.shared.map((s) => s.label), ['Alarma halei']);
  });

  test('signing out forgets the companies and their sounds', () async {
    final org = store.addOrg('Fabrica');
    store.addMember(org, 'u-ana@firma.ro');
    store.sounds[org] = [(sound('Alarma halei'), SoundModel.tflite)];
    account.signInAs('ana@firma.ro');
    final orgs = create();
    await orgs.refresh();

    await account.signOut();
    await orgs.refresh();
    expect(orgs.memberships, isEmpty);
    expect(sounds.shared, isEmpty);
  });

  test('an answer to an alarm reaches every company of the employee', () async {
    final a = store.addOrg('Fabrica');
    final b = store.addOrg('Sediu');
    store.addMember(a, 'u-ana@firma.ro');
    store.addMember(b, 'u-ana@firma.ro');
    account.signInAs('ana@firma.ro');
    final orgs = create();
    await orgs.refresh();

    await orgs.answerAlarm(SoundKind.fireAlarm, AlarmAnswerStatus.safe);
    expect(store.alarms.length, 2);
    for (final event in store.alarms.keys) {
      expect(store.answers[event]!['u-ana@firma.ro']!.status, AlarmAnswerStatus.safe);
    }
  });

  test('a failed refresh keeps what was loaded', () async {
    final org = store.addOrg('Fabrica');
    store.addMember(org, 'u-ana@firma.ro');
    account.signInAs('ana@firma.ro');
    final orgs = create();
    await orgs.refresh();

    final broken = Organizations(store: _FailingStore(), account: account, sounds: sounds, model: SoundModel.tflite);
    await broken.refresh();
    expect(broken.memberships, isEmpty);
    expect(orgs.memberships, hasLength(1));
  });
}

class _FailingStore extends FakeOrgStore {
  _FailingStore() : super(FakeAccountService());

  @override
  Future<List<OrgMembership>> myOrganizations() => Future.error(StateError('offline'));
}
