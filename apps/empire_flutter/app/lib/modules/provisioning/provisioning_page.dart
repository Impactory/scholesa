import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../ui/common/loading.dart';
import '../../ui/common/empty_state.dart';
import 'provisioning_models.dart';

/// Provisioning page for site admins
class ProvisioningPage extends StatefulWidget {
  const ProvisioningPage({super.key});

  @override
  State<ProvisioningPage> createState() => _ProvisioningPageState();
}

class _ProvisioningPageState extends State<ProvisioningPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provisioning'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.child_care), text: 'Learners'),
            Tab(icon: Icon(Icons.family_restroom), text: 'Parents'),
            Tab(icon: Icon(Icons.link), text: 'Links'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          _LearnersTab(),
          _ParentsTab(),
          _LinksTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final int currentTab = _tabController.index;
    
    switch (currentTab) {
      case 0:
        _showCreateLearnerDialog(context);
      case 1:
        _showCreateParentDialog(context);
      case 2:
        _showCreateLinkDialog(context);
    }
  }

  void _showCreateLearnerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateLearnerDialog(),
    );
  }

  void _showCreateParentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateParentDialog(),
    );
  }

  void _showCreateLinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateLinkDialog(),
    );
  }
}

/// Learners tab
class _LearnersTab extends StatelessWidget {
  const _LearnersTab();

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final List<_MockLearner> mockLearners = <_MockLearner>[
      _MockLearner(id: '1', name: 'Alice Johnson', grade: 3),
      _MockLearner(id: '2', name: 'Bob Smith', grade: 4),
      _MockLearner(id: '3', name: 'Charlie Brown', grade: 3),
    ];

    if (mockLearners.isEmpty) {
      return const EmptyState(
        icon: Icons.child_care,
        title: 'No learners yet',
        message: 'Add learners to your site to get started.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockLearners.length,
      itemBuilder: (BuildContext context, int index) {
        final _MockLearner learner = mockLearners[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(learner.name[0]),
            ),
            title: Text(learner.name),
            subtitle: Text('Grade ${learner.grade}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
        );
      },
    );
  }
}

class _MockLearner {

  _MockLearner({required this.id, required this.name, required this.grade});
  final String id;
  final String name;
  final int grade;
}

/// Parents tab
class _ParentsTab extends StatelessWidget {
  const _ParentsTab();

  @override
  Widget build(BuildContext context) {
    final List<_MockParent> mockParents = <_MockParent>[
      _MockParent(id: '1', name: 'John Johnson', email: 'john@example.com'),
      _MockParent(id: '2', name: 'Jane Smith', email: 'jane@example.com'),
    ];

    if (mockParents.isEmpty) {
      return const EmptyState(
        icon: Icons.family_restroom,
        title: 'No parents yet',
        message: 'Add parent accounts to link with learners.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockParents.length,
      itemBuilder: (BuildContext context, int index) {
        final _MockParent parent = mockParents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(parent.name[0], style: const TextStyle(color: Colors.white)),
            ),
            title: Text(parent.name),
            subtitle: Text(parent.email),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
        );
      },
    );
  }
}

class _MockParent {

  _MockParent({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;
}

/// Guardian links tab
class _LinksTab extends StatelessWidget {
  const _LinksTab();

  @override
  Widget build(BuildContext context) {
    final List<_MockLink> mockLinks = <_MockLink>[
      _MockLink(
        id: '1',
        parentName: 'John Johnson',
        learnerName: 'Alice Johnson',
        relationship: 'Father',
        isPrimary: true,
      ),
      _MockLink(
        id: '2',
        parentName: 'Jane Smith',
        learnerName: 'Bob Smith',
        relationship: 'Mother',
        isPrimary: true,
      ),
    ];

    if (mockLinks.isEmpty) {
      return const EmptyState(
        icon: Icons.link,
        title: 'No guardian links',
        message: 'Link parents to learners to enable family access.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockLinks.length,
      itemBuilder: (BuildContext context, int index) {
        final _MockLink link = mockLinks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.link, size: 32),
            title: Text('${link.parentName} → ${link.learnerName}'),
            subtitle: Row(
              children: <Widget>[
                Text(link.relationship),
                if (link.isPrimary) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Primary',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, link),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, _MockLink link) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Link'),
        content: Text(
          'Remove the guardian link between ${link.parentName} and ${link.learnerName}?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link removed')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MockLink {

  _MockLink({
    required this.id,
    required this.parentName,
    required this.learnerName,
    required this.relationship,
    required this.isPrimary,
  });
  final String id;
  final String parentName;
  final String learnerName;
  final String relationship;
  final bool isPrimary;
}

/// Create learner dialog
class _CreateLearnerDialog extends StatefulWidget {
  const _CreateLearnerDialog();

  @override
  State<_CreateLearnerDialog> createState() => _CreateLearnerDialogState();
}

class _CreateLearnerDialogState extends State<_CreateLearnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  int? _selectedGrade;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Learner'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? false ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (String? v) {
                if (v?.isEmpty ?? false) return 'Required';
                if (!v!.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Grade Level',
                prefixIcon: Icon(Icons.school),
              ),
              items: List.generate(9, (int i) => i + 1)
                  .map((int g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (int? v) => setState(() => _selectedGrade = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Learner created')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Create parent dialog
class _CreateParentDialog extends StatefulWidget {
  const _CreateParentDialog();

  @override
  State<_CreateParentDialog> createState() => _CreateParentDialogState();
}

class _CreateParentDialogState extends State<_CreateParentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Parent'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? false ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (String? v) {
                if (v?.isEmpty ?? false) return 'Required';
                if (!v!.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Parent created')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Create guardian link dialog
class _CreateLinkDialog extends StatefulWidget {
  const _CreateLinkDialog();

  @override
  State<_CreateLinkDialog> createState() => _CreateLinkDialogState();
}

class _CreateLinkDialogState extends State<_CreateLinkDialog> {
  String? _selectedParent;
  String? _selectedLearner;
  String _relationship = 'Parent';
  bool _isPrimary = false;

  final List<String> _relationships = <String>['Parent', 'Father', 'Mother', 'Guardian', 'Grandparent', 'Other'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Guardian Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            value: _selectedParent,
            decoration: const InputDecoration(
              labelText: 'Parent',
              prefixIcon: Icon(Icons.family_restroom),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: '1', child: Text('John Johnson')),
              DropdownMenuItem(value: '2', child: Text('Jane Smith')),
            ],
            onChanged: (String? v) => setState(() => _selectedParent = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLearner,
            decoration: const InputDecoration(
              labelText: 'Learner',
              prefixIcon: Icon(Icons.child_care),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: '1', child: Text('Alice Johnson')),
              DropdownMenuItem(value: '2', child: Text('Bob Smith')),
              DropdownMenuItem(value: '3', child: Text('Charlie Brown')),
            ],
            onChanged: (String? v) => setState(() => _selectedLearner = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _relationship,
            decoration: const InputDecoration(
              labelText: 'Relationship',
              prefixIcon: Icon(Icons.people),
            ),
            items: _relationships
                .map((String r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (String? v) => setState(() => _relationship = v ?? 'Parent'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Primary guardian'),
            subtitle: const Text('Receives all notifications'),
            value: _isPrimary,
            onChanged: (bool v) => setState(() => _isPrimary = v),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedParent != null && _selectedLearner != null
              ? () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardian link created')),
                  );
                }
              : null,
          child: const Text('Create Link'),
        ),
      ],
    );
  }
}
