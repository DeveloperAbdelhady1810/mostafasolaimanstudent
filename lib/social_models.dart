/// What the server tells the app about "Continue with Google / Apple" (GET /auth/social/config).
class SocialConfig {
  const SocialConfig({required this.googleEnabled, this.googleServerClientId, required this.appleEnabled});

  final bool googleEnabled;

  /// The Google WEB client id the phone asks Google to issue its identity token for.
  final String? googleServerClientId;
  final bool appleEnabled;

  factory SocialConfig.fromJson(Map<String, dynamic> j) => SocialConfig(
        googleEnabled: j['google_enabled'] == true,
        googleServerClientId: j['google_server_client_id']?.toString(),
        appleEnabled: j['apple_enabled'] == true,
      );
}

/// A verified Google/Apple identity with no student account yet: the app must collect the profile.
class SocialPending {
  const SocialPending({required this.ticket, required this.email, required this.name});

  final String ticket;
  final String email;
  final String name;
}

/// The choices of the registration form (GET /auth/social/options) - the same ones the website validates against.
class RegistrationOptions {
  const RegistrationOptions({required this.stages, required this.studyModes, required this.zoomGroups});

  final List<StageOption> stages;
  final List<String> studyModes;
  final List<ZoomGroupOption> zoomGroups;

  StageOption? stage(String? key) => stages.where((s) => s.key == key).firstOrNull;

  factory RegistrationOptions.fromJson(Map<String, dynamic> j) => RegistrationOptions(
        stages: ((j['stages'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StageOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        studyModes: ((j['study_modes'] as List?) ?? const ['center', 'online']).map((e) => e.toString()).toList(),
        zoomGroups: ((j['zoom_groups'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ZoomGroupOption(id: (e['id'] as num).toInt(), name: e['name'].toString()))
            .toList(),
      );
}

class StageOption {
  const StageOption({required this.key, required this.nameAr, required this.grades});

  final String key; // primary | preparatory | secondary
  final String nameAr;
  final List<GradeOption> grades;

  GradeOption? grade(String? key) => grades.where((g) => g.key == key).firstOrNull;

  factory StageOption.fromJson(Map<String, dynamic> j) => StageOption(
        key: j['key'].toString(),
        nameAr: (j['name_ar'] ?? j['key']).toString(),
        grades: ((j['grades'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => GradeOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class GradeOption {
  const GradeOption({required this.key, required this.nameAr, required this.divisions});

  final String key; // grade_1 ...
  final String nameAr;
  final List<DivisionOption> divisions;

  factory GradeOption.fromJson(Map<String, dynamic> j) => GradeOption(
        key: j['key'].toString(),
        nameAr: (j['name_ar'] ?? j['key']).toString(),
        divisions: ((j['divisions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => DivisionOption(key: e['key'].toString(), nameAr: (e['name_ar'] ?? e['key']).toString()))
            .toList(),
      );
}

class DivisionOption {
  const DivisionOption({required this.key, required this.nameAr});
  final String key;
  final String nameAr;
}

class ZoomGroupOption {
  const ZoomGroupOption({required this.id, required this.name});
  final int id;
  final String name;
}
