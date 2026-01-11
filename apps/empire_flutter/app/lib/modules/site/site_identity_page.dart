import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Site identity resolution page
/// Based on docs/46_IDENTITY_MATCHING_RESOLUTION_SPEC.md
class SiteIdentityPage extends StatefulWidget {
  const SiteIdentityPage({super.key});

  @override
  State<SiteIdentityPage> createState() => _SiteIdentityPageState();
}

class _SiteIdentityPageState extends State<SiteIdentityPage> {
  final List<_IdentityMatch> _pendingMatches = <_IdentityMatch>[
    _IdentityMatch(
      id: '1',
      localName: 'Oliver Thompson',
      externalName: 'O. Thompson',
      provider: 'Google Classroom',
      confidence: 0.92,
      status: _MatchStatus.pending,
    ),
    _IdentityMatch(
      id: '2',
      localName: 'Emma Smith',
      externalName: 'Emma S.',
      provider: 'GitHub',
      confidence: 0.85,
      status: _MatchStatus.pending,
    ),
    _IdentityMatch(
      id: '3',
      localName: 'Liam Martinez',
      externalName: 'liamm_student',
      provider: 'GitHub',
      confidence: 0.65,
      status: _MatchStatus.pending,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Identity Resolution'),
        backgroundColor: const Color(0xFF64748B),
        foregroundColor: Colors.white,
      ),
      body: _pendingMatches.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildHeader(),
                const SizedBox(height: 16),
                ..._pendingMatches.map((match) => _buildMatchCard(match)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Review and confirm matches between local accounts and external provider accounts.',
              style: TextStyle(
                fontSize: 13,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Identities Resolved',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending identity matches to review',
            style: TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(_IdentityMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildProviderIcon(match.provider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        match.provider,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Match confidence: ${(match.confidence * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getConfidenceColor(match.confidence),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildConfidenceIndicator(match.confidence),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildIdentityColumn('Local Account', match.localName, Icons.person_rounded),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, size: 20, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: _buildIdentityColumn('External Account', match.externalName, Icons.cloud_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleIgnore(match),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve Match'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderIcon(String provider) {
    IconData icon;
    Color color;
    switch (provider.toLowerCase()) {
      case 'google classroom':
        icon = Icons.school_rounded;
        color = Colors.blue;
      case 'github':
        icon = Icons.code_rounded;
        color = Colors.black87;
      default:
        icon = Icons.cloud_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildIdentityColumn(String label, String name, IconData icon) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ScholesaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: ScholesaColors.textSecondary, size: 24),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: confidence,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(confidence)),
            strokeWidth: 4,
          ),
        ),
        Text(
          '${(confidence * 100).toInt()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getConfidenceColor(confidence),
          ),
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }

  void _handleApprove(_IdentityMatch match) {
    setState(() {
      _pendingMatches.removeWhere((_IdentityMatch m) => m.id == match.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Matched ${match.localName} with ${match.externalName}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleIgnore(_IdentityMatch match) {
    setState(() {
      _pendingMatches.removeWhere((_IdentityMatch m) => m.id == match.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Match ignored'),
        backgroundColor: Colors.grey,
      ),
    );
  }
}

enum _MatchStatus { pending, approved, rejected }

class _IdentityMatch {
  const _IdentityMatch({
    required this.id,
    required this.localName,
    required this.externalName,
    required this.provider,
    required this.confidence,
    required this.status,
  });

  final String id;
  final String localName;
  final String externalName;
  final String provider;
  final double confidence;
  final _MatchStatus status;
}
