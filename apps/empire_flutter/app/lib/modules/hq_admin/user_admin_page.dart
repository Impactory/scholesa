import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart' show UserRole, UserRoleExtension;
import '../../ui/theme/scholesa_theme.dart';
import '../../ui/widgets/cards.dart';
import 'user_models.dart';
import 'user_admin_service.dart';

/// HQ User Administration Page
/// Beautiful colorful UI for managing all platform users
class UserAdminPage extends StatefulWidget {
  const UserAdminPage({super.key});

  @override
  State<UserAdminPage> createState() => _UserAdminPageState();
}

class _UserAdminPageState extends State<UserAdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load users on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserAdminService>().loadUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq.withOpacity(0.05),
              Colors.white,
              ScholesaColors.purple.withOpacity(0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(),
              _buildStatsRow(),
              _buildSearchAndFilters(),
              _buildTabBar(),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[ScholesaColors.hq, ScholesaColors.purple],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ScholesaColors.hq.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'User Administration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.hq,
                ),
              ),
              Text(
                'Manage all platform users',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.read<UserAdminService>().loadUsers(),
            icon: const Icon(Icons.refresh, color: ScholesaColors.hq),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<UserAdminService>(
      builder: (BuildContext context, UserAdminService service, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.people,
                  value: service.totalUsers.toString(),
                  label: 'Total Users',
                  color: ScholesaColors.hq,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.check_circle,
                  value: service.activeUsers.toString(),
                  label: 'Active',
                  color: ScholesaColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.school,
                  value: service.learnerCount.toString(),
                  label: 'Learners',
                  color: ScholesaColors.learner,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.person,
                  value: service.educatorCount.toString(),
                  label: 'Educators',
                  color: ScholesaColors.educator,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Consumer<UserAdminService>(
      builder: (BuildContext context, UserAdminService service, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) => service.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    prefixIcon: const Icon(Icons.search, color: ScholesaColors.hq),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              service.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'All Roles',
                      selected: service.roleFilter == null,
                      onTap: () => service.setRoleFilter(null),
                    ),
                    ...UserRole.values.map((UserRole role) => _FilterChip(
                      label: role.label,
                      selected: service.roleFilter == role,
                      onTap: () => service.setRoleFilter(role),
                      color: _getRoleColor(role),
                    )),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 24, color: Colors.grey[300]),
                    const SizedBox(width: 16),
                    _FilterChip(
                      label: 'All Status',
                      selected: service.statusFilter == null,
                      onTap: () => service.setStatusFilter(null),
                    ),
                    ...UserStatus.values.where((UserStatus s) => s != UserStatus.deactivated).map((UserStatus status) => _FilterChip(
                      label: status.label,
                      selected: service.statusFilter == status,
                      onTap: () => service.setStatusFilter(status),
                      color: _getStatusColor(status),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: ScholesaColors.hq,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        tabs: const <Widget>[
          Tab(text: 'All Users'),
          Tab(text: 'Sites'),
          Tab(text: 'Audit Log'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _buildUsersList(),
        _buildSitesList(),
        _buildAuditLog(),
      ],
    );
  }

  Widget _buildUsersList() {
    return Consumer<UserAdminService>(
      builder: (BuildContext context, UserAdminService service, _) {
        if (service.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: ScholesaColors.hq),
          );
        }

        if (service.users.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No users found',
            subtitle: 'Try adjusting your filters',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.users.length,
          itemBuilder: (BuildContext context, int index) {
            final UserModel user = service.users[index];
            return _UserCard(
              user: user,
              sites: service.sites,
              onTap: () => _showUserDetails(user),
            );
          },
        );
      },
    );
  }

  Widget _buildSitesList() {
    return Consumer<UserAdminService>(
      builder: (BuildContext context, UserAdminService service, _) {
        if (service.sites.isEmpty) {
          return _buildEmptyState(
            icon: Icons.location_city_outlined,
            title: 'No sites available',
            subtitle: 'Sites will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.sites.length,
          itemBuilder: (BuildContext context, int index) {
            final SiteModel site = service.sites[index];
            return _SiteCard(site: site);
          },
        );
      },
    );
  }

  Widget _buildAuditLog() {
    return Consumer<UserAdminService>(
      builder: (BuildContext context, UserAdminService service, _) {
        if (service.auditLogs.isEmpty) {
          // Load audit logs when tab is viewed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            service.loadAuditLogs();
          });
          return const Center(
            child: CircularProgressIndicator(color: ScholesaColors.hq),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.auditLogs.length,
          itemBuilder: (BuildContext context, int index) {
            final AuditLogEntry log = service.auditLogs[index];
            return _AuditLogCard(log: log);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ScholesaColors.hq.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: ScholesaColors.hq),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateUserDialog(),
      backgroundColor: ScholesaColors.hq,
      icon: const Icon(Icons.person_add),
      label: const Text('Add User'),
    );
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _UserDetailsSheet(user: user),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateUserDialog(),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return ScholesaColors.learner;
      case UserRole.educator:
        return ScholesaColors.educator;
      case UserRole.parent:
        return ScholesaColors.parent;
      case UserRole.site:
        return ScholesaColors.site;
      case UserRole.partner:
        return ScholesaColors.partner;
      case UserRole.hq:
        return ScholesaColors.hq;
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return ScholesaColors.success;
      case UserStatus.suspended:
        return ScholesaColors.error;
      case UserStatus.pending:
        return ScholesaColors.warning;
      case UserStatus.deactivated:
        return Colors.grey;
    }
  }
}

// ==================== Sub Widgets ====================

class _StatMiniCard extends StatelessWidget {

  const _StatMiniCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? ScholesaColors.hq;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? chipColor : chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : chipColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {

  const _UserCard({
    required this.user,
    required this.sites,
    required this.onTap,
  });
  final UserModel user;
  final List<SiteModel> sites;
  final VoidCallback onTap;

  Color get _roleColor {
    switch (user.role) {
      case UserRole.learner:
        return ScholesaColors.learner;
      case UserRole.educator:
        return ScholesaColors.educator;
      case UserRole.parent:
        return ScholesaColors.parent;
      case UserRole.site:
        return ScholesaColors.site;
      case UserRole.partner:
        return ScholesaColors.partner;
      case UserRole.hq:
        return ScholesaColors.hq;
    }
  }

  Color get _statusColor {
    switch (user.status) {
      case UserStatus.active:
        return ScholesaColors.success;
      case UserStatus.suspended:
        return ScholesaColors.error;
      case UserStatus.pending:
        return ScholesaColors.warning;
      case UserStatus.deactivated:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _roleColor.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[_roleColor.withOpacity(0.8), _roleColor],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _roleColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(user.displayName ?? user.email),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            user.displayName ?? 'No Name',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.status.label,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.role.label,
                            style: TextStyle(
                              color: _roleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user.siteIds.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Text(
                            '${user.siteIds.length} site${user.siteIds.length > 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final List<String> parts = name.split(RegExp(r'[\s@]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}

class _SiteCard extends StatelessWidget {

  const _SiteCard({required this.site});
  final SiteModel site;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ScholesaColors.site.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[ScholesaColors.site.withOpacity(0.8), ScholesaColors.site],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.location_city, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    site.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (site.location != null)
                    Text(
                      site.location!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _SiteStatChip(
                        icon: Icons.people,
                        value: site.userCount.toString(),
                        label: 'Users',
                      ),
                      const SizedBox(width: 12),
                      _SiteStatChip(
                        icon: Icons.school,
                        value: site.learnerCount.toString(),
                        label: 'Learners',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteStatChip extends StatelessWidget {

  const _SiteStatChip({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {

  const _AuditLogCard({required this.log});
  final AuditLogEntry log;

  IconData get _actionIcon {
    if (log.action.contains('created')) return Icons.add_circle;
    if (log.action.contains('suspended')) return Icons.block;
    if (log.action.contains('role')) return Icons.swap_horiz;
    if (log.action.contains('site')) return Icons.location_on;
    return Icons.edit;
  }

  Color get _actionColor {
    if (log.action.contains('created')) return ScholesaColors.success;
    if (log.action.contains('suspended')) return ScholesaColors.error;
    if (log.action.contains('role')) return ScholesaColors.hq;
    return ScholesaColors.site;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_actionIcon, color: _actionColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatAction(log.action),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'by ${log.actorEmail}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(log.timestamp),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAction(String action) {
    return action.replaceAll('user.', '').replaceAll('_', ' ').split(' ').map((String w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ==================== Dialogs & Sheets ====================

class _UserDetailsSheet extends StatelessWidget {

  const _UserDetailsSheet({required this.user});
  final UserModel user;

  Color get _roleColor {
    switch (user.role) {
      case UserRole.learner:
        return ScholesaColors.learner;
      case UserRole.educator:
        return ScholesaColors.educator;
      case UserRole.parent:
        return ScholesaColors.parent;
      case UserRole.site:
        return ScholesaColors.site;
      case UserRole.partner:
        return ScholesaColors.partner;
      case UserRole.hq:
        return ScholesaColors.hq;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Header
                  Row(
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[_roleColor.withOpacity(0.8), _roleColor],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _roleColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(user.displayName ?? user.email),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.displayName ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    user.role.label,
                                    style: TextStyle(
                                      color: _roleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: user.status.label,
                                  color: _getStatusColor(user.status),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _ActionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        color: ScholesaColors.hq,
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        icon: user.status == UserStatus.suspended ? Icons.check_circle : Icons.block,
                        label: user.status == UserStatus.suspended ? 'Activate' : 'Suspend',
                        color: user.status == UserStatus.suspended ? ScholesaColors.success : ScholesaColors.error,
                        onTap: () => _toggleStatus(context),
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Change Role',
                        color: ScholesaColors.educator,
                        onTap: () => _showRoleChangeDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info sections
                  _InfoSection(
                    title: 'Account Details',
                    items: <_InfoItem>[
                      _InfoItem(icon: Icons.fingerprint, label: 'User ID', value: user.uid),
                      _InfoItem(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: _formatDate(user.createdAt),
                      ),
                      if (user.lastLoginAt != null)
                        _InfoItem(
                          icon: Icons.login,
                          label: 'Last Login',
                          value: _formatDate(user.lastLoginAt!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Site Access',
                    items: user.siteIds.isEmpty
                        ? <_InfoItem>[const _InfoItem(icon: Icons.location_off, label: 'No sites assigned', value: '')]
                        : user.siteIds.map((String s) => _InfoItem(
                            icon: Icons.location_on,
                            label: s,
                            value: '',
                          )).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final List<String> parts = name.split(RegExp(r'[\s@]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return ScholesaColors.success;
      case UserStatus.suspended:
        return ScholesaColors.error;
      case UserStatus.pending:
        return ScholesaColors.warning;
      case UserStatus.deactivated:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _toggleStatus(BuildContext context) {
    final UserAdminService service = context.read<UserAdminService>();
    final UserStatus newStatus = user.status == UserStatus.suspended
        ? UserStatus.active
        : UserStatus.suspended;
    service.updateUserStatus(user.uid, newStatus);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('User ${newStatus == UserStatus.active ? 'activated' : 'suspended'}'),
        backgroundColor: newStatus == UserStatus.active ? ScholesaColors.success : ScholesaColors.error,
      ),
    );
  }

  void _showRoleChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.map((UserRole role) => ListTile(
            leading: Icon(
              _getRoleIcon(role),
              color: _getRoleColorFor(role),
            ),
            title: Text(role.label),
            selected: user.role == role,
            onTap: () {
              context.read<UserAdminService>().updateUserRole(user.uid, role);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Role changed to ${role.label}'),
                  backgroundColor: ScholesaColors.success,
                ),
              );
            },
          )).toList(),
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return Icons.school;
      case UserRole.educator:
        return Icons.person;
      case UserRole.parent:
        return Icons.family_restroom;
      case UserRole.site:
        return Icons.location_city;
      case UserRole.partner:
        return Icons.handshake;
      case UserRole.hq:
        return Icons.admin_panel_settings;
    }
  }

  Color _getRoleColorFor(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return ScholesaColors.learner;
      case UserRole.educator:
        return ScholesaColors.educator;
      case UserRole.parent:
        return ScholesaColors.parent;
      case UserRole.site:
        return ScholesaColors.site;
      case UserRole.partner:
        return ScholesaColors.partner;
      case UserRole.hq:
        return ScholesaColors.hq;
    }
  }
}

class _ActionButton extends StatelessWidget {

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: <Widget>[
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {

  const _InfoSection({required this.title, required this.items});
  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.learner;
  final List<String> _selectedSites = <String>[];
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserAdminService service = context.read<UserAdminService>();
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ScholesaColors.hq.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add, color: ScholesaColors.hq),
          ),
          const SizedBox(width: 12),
          const Text('Create New User'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (String? v) => v?.contains('@') ?? false ? null : 'Invalid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (String? v) => v?.isNotEmpty ?? false ? null : 'Required',
              ),
              const SizedBox(height: 16),
              Text('Role', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserRole.values.map((UserRole role) {
                  final Color color = _getRoleColor(role);
                  final bool isSelected = _selectedRole == role;
                  return ChoiceChip(
                    label: Text(role.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedRole = role),
                    selectedColor: color.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Sites', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: service.sites.map((SiteModel site) {
                  final bool isSelected = _selectedSites.contains(site.id);
                  return FilterChip(
                    label: Text(site.name),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedSites.add(site.id);
                        } else {
                          _selectedSites.remove(site.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: ScholesaColors.hq,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return ScholesaColors.learner;
      case UserRole.educator:
        return ScholesaColors.educator;
      case UserRole.parent:
        return ScholesaColors.parent;
      case UserRole.site:
        return ScholesaColors.site;
      case UserRole.partner:
        return ScholesaColors.partner;
      case UserRole.hq:
        return ScholesaColors.hq;
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final UserAdminService service = context.read<UserAdminService>();
    final UserModel? result = await service.createUser(
      email: _emailController.text,
      displayName: _nameController.text,
      role: _selectedRole,
      siteIds: _selectedSites,
    );

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${result.displayName} created'),
          backgroundColor: ScholesaColors.success,
        ),
      );
    }
  }
}
