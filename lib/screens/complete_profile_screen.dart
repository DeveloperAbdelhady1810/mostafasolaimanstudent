import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_client.dart';
import '../social_models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shown after "Continue with Google / Apple" when the email has no student account yet. It asks for the
/// same details as the website's sign-up form; the server creates the student, their parent record and profile.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.pending, this.options});

  final SocialPending pending;

  /// Preloaded choices (tests); normally fetched from the server.
  final RegistrationOptions? options;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.pending.name);
  final _phone = TextEditingController();
  final _parentPhone = TextEditingController();
  final _school = TextEditingController();
  final _age = TextEditingController();

  RegistrationOptions? _options;
  bool _loadingOptions = true;
  bool _optionsFailed = false;

  String? _stage;
  String? _grade;
  String? _division;
  String? _mode;
  int? _zoomGroup;
  String? _gender;

  bool _busy = false;
  String? _error;

  /// Messages the server returned for specific fields (shown under that field until it is edited).
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    if (widget.options != null) {
      _options = widget.options;
      _loadingOptions = false;
    } else {
      _loadOptions();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _parentPhone, _school, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsFailed = false;
    });
    try {
      final o = await context.read<AuthProvider>().registrationOptions();
      if (mounted) setState(() => _options = o);
    } catch (_) {
      if (mounted) setState(() => _optionsFailed = true);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  String? _fieldError(String field) => _serverErrors[field];

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  String? _required(String field, String? value) {
    final server = _fieldError(field);
    if (server != null) return server;
    return (value == null || value.trim().isEmpty) ? context.trRead('field_required') : null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().completeProfile(widget.pending.ticket, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'parent_phone': _parentPhone.text.trim(),
        'education_stage': _stage,
        'grade': _grade,
        if (_division != null) 'division': _division,
        'study_mode': _mode,
        if (_mode == 'zoom') 'zoom_group_id': _zoomGroup,
        'school': _school.text.trim(),
        'gender': _gender,
        'age': int.tryParse(_age.text.trim()),
      });
      // Signed in: AuthGate now shows the app, but this page sits on top of it - close everything above.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 422 && e.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = e.fieldErrors);
        _form.currentState!.validate();
      } else {
        setState(() => _error = _messageFor(e));
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.trRead('err_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(ApiException e) {
    if (e.isOffline) return context.trRead('err_network');
    if (e.status == 410) return context.trRead('err_social_expired');
    if (e.status == 403) return context.trRead(e.code == 'not_student' ? 'err_not_student' : 'err_blocked');
    if (e.status == 429) return context.trRead('err_too_many');
    return context.trRead('err_generic');
  }

  String _stageLabel(StageOption s, LocaleProvider lp) {
    final en = lp.t('stage_${s.key}');
    return lp.isArabic ? s.nameAr : '${s.nameAr}  -  $en';
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profile_title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 12), child: LanguageToggle())],
      ),
      body: SafeArea(
        child: _loadingOptions
            ? const Center(child: CircularProgressIndicator(color: Brand.primary))
            : _optionsFailed || _options == null
                ? EmptyStateRetry(message: context.tr('options_failed'), retryLabel: context.tr('retry'), onRetry: _loadOptions)
                : _buildForm(context, lp, _options!),
      ),
    );
  }

  Widget _buildForm(BuildContext context, LocaleProvider lp, RegistrationOptions o) {
    final stage = o.stage(_stage);
    final grade = stage?.grade(_grade);
    final divisions = grade?.divisions ?? const <DivisionOption>[];
    final modes = o.studyModes.where((m) => m != 'zoom' || o.zoomGroups.isNotEmpty).toList();

    InputDecoration deco(String labelKey, {String? hintKey, IconData? icon}) => InputDecoration(
          labelText: context.tr(labelKey),
          hintText: hintKey == null ? null : context.tr(hintKey),
          prefixIcon: icon == null ? null : Icon(icon),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('profile_intro'), style: const TextStyle(fontSize: 14.5, height: 1.5, color: Brand.muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Brand.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.mark_email_read_outlined, size: 18, color: Brand.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(widget.pending.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.primaryDark, fontSize: 13.5)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          TextFormField(
            key: const Key('f_name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('full_name', icon: Icons.person_outline_rounded),
            onChanged: (_) => _clearServerError('name'),
            validator: (v) => _required('name', v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('f_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('your_phone', hintKey: 'phone_hint', icon: Icons.phone_outlined),
            onChanged: (_) => _clearServerError('phone'),
            validator: (v) => _required('phone', v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('f_parent_phone'),
            controller: _parentPhone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('parent_phone', hintKey: 'phone_hint', icon: Icons.family_restroom_outlined),
            onChanged: (_) => _clearServerError('parent_phone'),
            validator: (v) => _required('parent_phone', v),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            key: const Key('f_stage'),
            isExpanded: true,
            initialValue: _stage,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('education_stage', icon: Icons.school_outlined),
            items: [for (final s in o.stages) DropdownMenuItem(value: s.key, child: Text(_stageLabel(s, lp)))],
            onChanged: (v) => setState(() {
              _stage = v;
              _grade = null;
              _division = null;
              _clearServerError('education_stage');
            }),
            validator: (v) => _required('education_stage', v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('f_grade_$_stage'),
            isExpanded: true,
            initialValue: _grade,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('grade', icon: Icons.class_outlined),
            items: [for (final g in stage?.grades ?? const <GradeOption>[]) DropdownMenuItem(value: g.key, child: Text(g.nameAr))],
            onChanged: stage == null
                ? null
                : (v) => setState(() {
                      _grade = v;
                      _division = null;
                      _clearServerError('grade');
                    }),
            validator: (v) => _required('grade', v),
          ),
          if (divisions.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('f_division_${_stage}_$_grade'),
              isExpanded: true,
              initialValue: _division,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: deco('division', icon: Icons.account_tree_outlined),
              items: [for (final d in divisions) DropdownMenuItem(value: d.key, child: Text(d.nameAr))],
              onChanged: (v) => setState(() {
                _division = v;
                _clearServerError('division');
              }),
              validator: (v) => _required('division', v),
            ),
          ],
          const SizedBox(height: 14),

          FormField<String>(
            key: const Key('f_mode'),
            initialValue: _mode,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) => _required('study_mode', _mode),
            builder: (state) => _LabeledChoice(
              label: context.tr('study_mode'),
              error: state.errorText,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                style: SegmentedButton.styleFrom(selectedBackgroundColor: Brand.primary, selectedForegroundColor: Colors.white),
                segments: [for (final m in modes) ButtonSegment(value: m, label: Text(context.tr('mode_$m')))],
                selected: {if (_mode != null) _mode!},
                onSelectionChanged: (s) {
                  setState(() {
                    _mode = s.isEmpty ? null : s.first;
                    if (_mode != 'zoom') _zoomGroup = null;
                    _clearServerError('study_mode');
                  });
                  state.didChange(_mode);
                },
              ),
            ),
          ),
          if (_mode == 'zoom') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: const Key('f_zoom_group'),
              isExpanded: true,
              initialValue: _zoomGroup,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: deco('zoom_group', icon: Icons.videocam_outlined),
              items: [for (final g in o.zoomGroups) DropdownMenuItem(value: g.id, child: Text(g.name))],
              onChanged: (v) => setState(() {
                _zoomGroup = v;
                _clearServerError('zoom_group_id');
              }),
              validator: (v) => _fieldError('zoom_group_id') ?? (v == null ? context.trRead('field_required') : null),
            ),
          ],
          const SizedBox(height: 14),

          TextFormField(
            key: const Key('f_school'),
            controller: _school,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('school', icon: Icons.apartment_outlined),
            onChanged: (_) => _clearServerError('school'),
            validator: (v) => _required('school', v),
          ),
          const SizedBox(height: 14),

          FormField<String>(
            key: const Key('f_gender'),
            initialValue: _gender,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) => _required('gender', _gender),
            builder: (state) => _LabeledChoice(
              label: context.tr('gender'),
              error: state.errorText,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                style: SegmentedButton.styleFrom(selectedBackgroundColor: Brand.primary, selectedForegroundColor: Colors.white),
                segments: [
                  ButtonSegment(value: 'male', label: Text(context.tr('male'))),
                  ButtonSegment(value: 'female', label: Text(context.tr('female'))),
                ],
                selected: {if (_gender != null) _gender!},
                onSelectionChanged: (s) {
                  setState(() {
                    _gender = s.isEmpty ? null : s.first;
                    _clearServerError('gender');
                  });
                  state.didChange(_gender);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('f_age'),
            controller: _age,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: deco('age', icon: Icons.cake_outlined),
            onChanged: (_) => _clearServerError('age'),
            validator: (v) {
              final server = _fieldError('age');
              if (server != null) return server;
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return context.trRead('field_required');
              return (n < 10 || n > 30) ? context.trRead('age_invalid') : null;
            },
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Brand.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Brand.danger.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Brand.danger, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(key: const Key('f_submit'), label: context.tr('create_account'), loading: _busy, onPressed: _submit),
        ]),
      ),
    );
  }
}

class _LabeledChoice extends StatelessWidget {
  const _LabeledChoice({required this.label, required this.child, this.error});

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Brand.muted)),
      ),
      SizedBox(width: double.infinity, child: child),
      if (error != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
          child: Text(error!, style: const TextStyle(fontSize: 12, color: Brand.danger)),
        ),
    ]);
  }
}
