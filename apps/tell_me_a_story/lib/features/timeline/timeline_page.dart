import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/invite_api.dart';
import '../invites/invite_accept.dart';
import '../invites/invite_modal.dart';

/// Signed-in home stub. Full timeline UX is M6.
/// M2: `+ Invite` opens Email/Link modal (chrome locks).
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, this.api});

  final InviteGateway? api;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final InviteGateway _api;
  String? _familyId;
  var _loadingFamily = true;
  var _inviteHandled = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InviteApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _api.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _loadingFamily = false;
      });
      await _maybeAcceptInvite();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFamily = false);
    }
  }

  Future<void> _maybeAcceptInvite() async {
    if (_inviteHandled || !mounted) return;
    _inviteHandled = true;
    final uri = GoRouterState.of(context).uri;
    if (!uri.queryParameters.containsKey('invite')) return;
    await acceptInviteFromUriIfPresent(
      context: context,
      uri: uri,
      api: _api,
    );
  }

  Future<void> _openInvite() async {
    var familyId = _familyId;
    if (familyId == null) {
      // Data/API bootstrap when inviting without membership (no Create Family screen).
      familyId = await _api.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(context, familyId: familyId!, api: _api);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          TextButton(
            onPressed: _loadingFamily ? null : _openInvite,
            child: const Text('+ Invite'),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Text('Timeline'),
        ),
      ),
    );
  }
}
