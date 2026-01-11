import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class PartnerContractsScreen extends StatefulWidget {
  const PartnerContractsScreen({super.key});

  @override
  State<PartnerContractsScreen> createState() => _PartnerContractsScreenState();
}

class _PartnerContractsScreenState extends State<PartnerContractsScreen> {
  late Future<List<PartnerContractModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PartnerContractModel>> _load() async {
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return <PartnerContractModel>[];
    final partnerOrgs = await PartnerOrgRepository().listMine(userId);
    if (partnerOrgs.isEmpty) return <PartnerContractModel>[];
    final partnerOrgId = partnerOrgs.first.id;
    final contracts = await PartnerContractRepository().listByOrg(partnerOrgId, limit: 50);
    return contracts;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contracts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PartnerContractModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final contracts = snapshot.data ?? <PartnerContractModel>[];
            if (contracts.isEmpty) {
              return const Center(child: Text('No contracts available.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: contracts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = contracts[index];
                return ListTile(
                  leading: const Icon(Icons.handshake),
                  title: Text(c.title),
                  subtitle: Text('${c.amount} ${c.currency} • Status: ${c.status}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
