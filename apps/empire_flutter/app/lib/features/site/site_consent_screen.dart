import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteConsentScreen extends StatefulWidget {
  const SiteConsentScreen({super.key});

  @override
  State<SiteConsentScreen> createState() => _SiteConsentScreenState();
}

class _SiteConsentScreenState extends State<SiteConsentScreen> {
  late Future<_SafetyData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SafetyData> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return const _SafetyData();
    final consents = await MediaConsentRepository().listBySite(siteId, limit: 100);
    final pickups = await PickupAuthorizationRepository().listBySite(siteId, limit: 100);
    return _SafetyData(consents: consents, pickups: pickups);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consents & Pickup')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showConsentEditor(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_SafetyData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _SafetyData();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  title: 'Media Consent',
                  emptyText: 'No consents recorded.',
                  actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showConsentEditor())],
                  children: data.consents.map((c) => ListTile(
                        leading: const Icon(Icons.camera_alt_outlined),
                        title: Text('Learner ${c.learnerId} • ${c.consentStatus}'),
                        subtitle: Text('Photo: ${c.photoCaptureAllowed ? 'Y' : 'N'} • Marketing: ${c.marketingUseAllowed ? 'Y' : 'N'}'),
                        trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showConsentEditor(model: c)),
                      )).toList(),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Pickup Authorizations',
                  emptyText: 'No pickup authorizations recorded.',
                  actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showPickupEditor())],
                  children: data.pickups.map((p) => ListTile(
                        leading: const Icon(Icons.group),
                        title: Text('Learner ${p.learnerId}'),
                        subtitle: Text('Authorized: ${(p.authorizedPickup.map((e) => e['name']).whereType<String>().toList()).join(', ')}'),
                        trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showPickupEditor(model: p)),
                      )).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section({required String title, required String emptyText, List<Widget> children = const <Widget>[], List<Widget> actions = const <Widget>[]}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ...actions,
              ],
            ),
            const SizedBox(height: 8),
            if (children.isEmpty) Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _showConsentEditor({MediaConsentModel? model}) async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    if (siteId == null || siteId.isEmpty) return;

    final learnerController = TextEditingController(text: model?.learnerId ?? '');
    final startController = TextEditingController(text: model?.consentStartDate ?? '');
    final endController = TextEditingController(text: model?.consentEndDate ?? '');
    final docUrlController = TextEditingController(text: model?.consentDocumentUrl ?? '');
    String status = model?.consentStatus ?? 'active';
    bool photo = model?.photoCaptureAllowed ?? false;
    bool share = model?.shareWithLinkedParents ?? false;
    bool marketing = model?.marketingUseAllowed ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(model == null ? 'Add consent' : 'Edit consent'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: learnerController, decoration: const InputDecoration(labelText: 'Learner ID')),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const ['active', 'expired', 'revoked'].map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                    onChanged: (value) => setStateDialog(() => status = value ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  CheckboxListTile(
                    value: photo,
                    title: const Text('Allow photo capture'),
                    onChanged: (value) => setStateDialog(() => photo = value ?? false),
                  ),
                  CheckboxListTile(
                    value: share,
                    title: const Text('Share with linked parents'),
                    onChanged: (value) => setStateDialog(() => share = value ?? false),
                  ),
                  CheckboxListTile(
                    value: marketing,
                    title: const Text('Allow marketing use'),
                    onChanged: (value) => setStateDialog(() => marketing = value ?? false),
                  ),
                  TextField(controller: startController, decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)')),
                  TextField(controller: endController, decoration: const InputDecoration(labelText: 'End date (YYYY-MM-DD)')),
                  TextField(controller: docUrlController, decoration: const InputDecoration(labelText: 'Document URL')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (learnerController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    if (confirmed != true) return;
    final id = model?.id ?? '${siteId}_${learnerController.text.trim()}';
    final consent = MediaConsentModel(
      id: id,
      siteId: siteId,
      learnerId: learnerController.text.trim(),
      photoCaptureAllowed: photo,
      shareWithLinkedParents: share,
      marketingUseAllowed: marketing,
      consentStatus: status,
      consentStartDate: startController.text.trim().isEmpty ? null : startController.text.trim(),
      consentEndDate: endController.text.trim().isEmpty ? null : endController.text.trim(),
      consentDocumentUrl: docUrlController.text.trim().isEmpty ? null : docUrlController.text.trim(),
      createdAt: model?.createdAt,
      updatedAt: model?.updatedAt,
    );
    await MediaConsentRepository().upsert(consent);
    await _refresh();
  }

  Future<void> _showPickupEditor({PickupAuthorizationModel? model}) async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    final userId = appState.user?.uid;
    if (siteId == null || siteId.isEmpty || userId == null) return;

    final learnerController = TextEditingController(text: model?.learnerId ?? '');
    final namesController = TextEditingController(
      text: model == null
          ? ''
          : model.authorizedPickup.map((e) => e['name']).whereType<String>().join(', '),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(model == null ? 'Add pickup authorization' : 'Edit pickup authorization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: learnerController, decoration: const InputDecoration(labelText: 'Learner ID')),
              TextField(controller: namesController, decoration: const InputDecoration(labelText: 'Authorized names (comma separated)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (learnerController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final names = namesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((name) => <String, dynamic>{'name': name})
        .toList();

    final id = model?.id ?? '${siteId}_${learnerController.text.trim()}';
    final pickup = PickupAuthorizationModel(
      id: id,
      siteId: siteId,
      learnerId: learnerController.text.trim(),
      authorizedPickup: names,
      updatedBy: userId,
      createdAt: model?.createdAt,
      updatedAt: model?.updatedAt,
    );
    await PickupAuthorizationRepository().upsert(pickup);
    await _refresh();
  }
}

class _SafetyData {
  const _SafetyData({this.consents = const <MediaConsentModel>[], this.pickups = const <PickupAuthorizationModel>[]});

  final List<MediaConsentModel> consents;
  final List<PickupAuthorizationModel> pickups;
}
