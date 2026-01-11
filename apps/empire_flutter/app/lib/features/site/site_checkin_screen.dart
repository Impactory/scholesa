import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteCheckInScreen extends StatefulWidget {
  const SiteCheckInScreen({super.key});

  @override
  State<SiteCheckInScreen> createState() => _SiteCheckInScreenState();
}

class _SiteCheckInScreenState extends State<SiteCheckInScreen> {
  late Future<_CheckInData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<_CheckInData> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return const _CheckInData();
    final enrollments = await EnrollmentRepository().listBySite(siteId);
    final records = await SiteCheckInOutRepository().listBySiteAndDate(siteId: siteId, date: _today());
    return _CheckInData(enrollments: enrollments, records: records);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in / Check-out')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_CheckInData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _CheckInData();
            if (data.enrollments.isEmpty) {
              return const Center(child: Text('No enrollments for this site.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.enrollments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = data.enrollments[index];
                final record = data.records.firstWhere(
                  (r) => r.learnerId == e.learnerId,
                  orElse: () => SiteCheckInOutModel(
                    id: '',
                    siteId: e.siteId,
                    learnerId: e.learnerId,
                    date: _today(),
                    checkInAt: null,
                    checkInBy: null,
                    checkOutAt: null,
                    checkOutBy: null,
                    pickedUpByName: null,
                    latePickupFlag: null,
                    createdAt: null,
                    updatedAt: null,
                  ),
                );
                return ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text('Learner ${e.learnerId}'),
                  subtitle: Text(_statusText(record)),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => _checkIn(e), child: const Text('Check-in')),
                      TextButton(onPressed: () => _checkOut(e), child: const Text('Check-out')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _statusText(SiteCheckInOutModel r) {
    final checkIn = r.checkInAt?.toDate();
    final checkOut = r.checkOutAt?.toDate();
    if (checkIn == null && checkOut == null) return 'Not yet checked in';
    if (checkIn != null && checkOut == null) return 'In • ${checkIn.toLocal()}';
    if (checkIn != null && checkOut != null) return 'Out • ${checkOut.toLocal()}';
    return 'Status unknown';
  }

  Future<void> _checkIn(EnrollmentModel e) async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    if (userId == null) return;
    await SiteCheckInOutRepository().markCheckIn(siteId: e.siteId, learnerId: e.learnerId, userId: userId, date: _today());
    await _refresh();
  }

  Future<void> _checkOut(EnrollmentModel e) async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    if (userId == null) return;
    final auth = await PickupAuthorizationRepository().getByLearner(e.learnerId, e.siteId);
    final details = await _promptCheckoutDetails(auth?.authorizedPickup ?? const <Map<String, dynamic>>[]);
    if (details == null) return;
    await SiteCheckInOutRepository().markCheckOut(
      siteId: e.siteId,
      learnerId: e.learnerId,
      userId: userId,
      date: _today(),
      pickedUpByName: details.pickedUpByName,
      latePickupFlag: details.latePickupFlag,
    );
    await _refresh();
  }

  Future<_CheckoutDetails?> _promptCheckoutDetails(List<Map<String, dynamic>> authorizedPickup) async {
    final names = authorizedPickup.map((p) => p['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
    final controller = TextEditingController(text: names.isNotEmpty ? names.first : '');
    bool latePickup = false;
    return showDialog<_CheckoutDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Checkout details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (names.isNotEmpty)
                    DropdownMenu<String>(
                      initialSelection: controller.text.isNotEmpty ? controller.text : names.first,
                      dropdownMenuEntries:
                          names.map((n) => DropdownMenuEntry<String>(value: n, label: n)).toList(),
                      onSelected: (value) => setStateDialog(() => controller.text = value ?? ''),
                      label: const Text('Authorized picker'),
                    ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Picked up by (name)'),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: latePickup,
                        onChanged: (value) => setStateDialog(() => latePickup = value ?? false),
                      ),
                      const Text('Late pickup'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _CheckoutDetails(
                        pickedUpByName: controller.text.trim().isEmpty ? null : controller.text.trim(),
                        latePickupFlag: latePickup,
                      ),
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CheckInData {
  const _CheckInData({
    this.enrollments = const <EnrollmentModel>[],
    this.records = const <SiteCheckInOutModel>[],
  });

  final List<EnrollmentModel> enrollments;
  final List<SiteCheckInOutModel> records;
}

class _CheckoutDetails {
  const _CheckoutDetails({required this.pickedUpByName, required this.latePickupFlag});

  final String? pickedUpByName;
  final bool? latePickupFlag;
}
