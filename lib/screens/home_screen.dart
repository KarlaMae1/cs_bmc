import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../main.dart';
import '../models.dart';
import '../widgets.dart';
import 'record_detail.dart';
import 'record_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = store.current!;
    final pages = [
      const _Dashboard(),
      const _RecordsTab(),
      const _ProfileTab(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(['Dashboard', 'Records', 'Profile'][_tab])),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => pages[_tab],
      ),
      floatingActionButton: (me.isAdmin && _tab == 1)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Dashboard
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final me = store.current!;
    final recs = store.visibleRecords;
    final pending = recs.where((r) => r.status != 'Completed').length;
    final done = recs.where((r) => r.status == 'Completed').length;
    final remaining = recs.fold<double>(0, (s, r) => s + r.remaining);

    final upcoming =
        recs
            .where((r) => r.status != 'Completed' && r.dutyDate != null)
            .toList()
          ..sort((a, b) => a.dutyDate!.compareTo(b.dutyDate!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ProfileAvatar(
              name: me.name,
              photoUrl: store.profilePhotoUri(me.profilePhoto)?.toString(),
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${me.name}!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    me.isAdmin ? 'Admin / OSA' : 'Student',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatTile(
              'Active',
              '$pending',
              Icons.pending_actions,
              Colors.orange,
            ),
            const SizedBox(width: 10),
            _StatTile('Completed', '$done', Icons.check_circle, Colors.green),
            const SizedBox(width: 10),
            _StatTile(
              'Hours remaining',
              hoursText(remaining),
              Icons.timer,
              Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Upcoming duties', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No duties scheduled.'),
            ),
          )
        else
          ...upcoming
              .take(5)
              .map(
                (r) => Card(
                  child: ListTile(
                    leading: me.isAdmin
                        ? ProfileAvatar(
                            name: store.studentName(r.studentId),
                            photoUrl: store
                                .profilePhotoUri(
                                  store.userById(r.studentId)?.profilePhoto,
                                )
                                ?.toString(),
                            radius: 22,
                          )
                        : ProfileAvatar(
                            name: me.name,
                            photoUrl: store
                                .profilePhotoUri(me.profilePhoto)
                                ?.toString(),
                            radius: 22,
                          ),
                    title: Text(
                      me.isAdmin ? store.studentName(r.studentId) : r.violation,
                    ),
                    subtitle: Text(
                      '${dateFmt.format(r.dutyDate!)}${r.dutyTime.isEmpty ? '' : ' • ${r.dutyTime}'}\n${r.ticketNo}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordDetailScreen(recordId: r.id),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Records
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  String _query = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final me = store.current!;
    final q = _query.trim().toLowerCase();
    final list = store.visibleRecords.where((r) {
      if (_filter != 'All' && r.status != _filter) return false;
      if (q.isEmpty) return true;
      return r.ticketNo.toLowerCase().contains(q) ||
          r.violation.toLowerCase().contains(q) ||
          store.studentName(r.studentId).toLowerCase().contains(q) ||
          (store.userById(r.studentId)?.studentNo.toLowerCase().contains(q) ??
              false);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: me.isAdmin
                  ? 'Search students, tickets, or violations'
                  : 'Search tickets or violations',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['All', 'Pending', 'Ongoing', 'Completed']
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    store.visibleRecords.isEmpty
                        ? 'No records yet.'
                        : 'No matching results.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final CsRecord r = list[i];
                    return RecordCard(
                      record: r,
                      studentName: store.studentName(r.studentId),
                      studentPhotoUrl: store
                          .profilePhotoUri(
                            store.userById(r.studentId)?.profilePhoto,
                          )
                          ?.toString(),
                      showStudent: me.isAdmin,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordDetailScreen(recordId: r.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Profile
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _studentNo = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  Future<Uint8List>? _photoBytes;
  String? _editingUserId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _studentNo.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser user) {
    if (_editingUserId == user.id) return;
    _editingUserId = user.id;
    _name.text = user.name;
    _email.text = user.email;
    _studentNo.text = user.studentNo;
    _photo = null;
    _photoBytes = null;
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (photo != null && mounted) {
      setState(() {
        _photo = photo;
        _photoBytes = photo.readAsBytes();
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await store.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        studentNo: _studentNo.text.trim(),
        photo: _photo,
      );
      if (_photo != null && store.current?.profilePhoto == null) {
        throw const ApiException(
          'The profile was updated, but the photo was not saved. Please try again.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = store.current!;
    final cs = Theme.of(context).colorScheme;
    _syncControllers(me);
    final photoUrl = store.profilePhotoUri(me.profilePhoto);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Stack(
            children: [
              _photo != null
                  ? FutureBuilder<Uint8List>(
                      future: _photoBytes,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Icon(Icons.broken_image, color: cs.error);
                        }
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return ClipOval(
                          child: Image.memory(
                            snapshot.data!,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    )
                  : ProfileAvatar(
                      name: me.name,
                      photoUrl: photoUrl?.toString(),
                      radius: 52,
                    ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Change profile photo',
                  onPressed: _saving ? null : _pickPhoto,
                  icon: const Icon(Icons.camera_alt),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _saving ? null : _pickPhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose profile photo'),
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) =>
                    value == null ||
                        !RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value.trim())
                    ? 'Enter a valid email address.'
                    : null,
              ),
              if (!me.isAdmin) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentNo,
                  decoration: const InputDecoration(
                    labelText: 'Student number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your student number.'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Role'),
                subtitle: Text(me.isAdmin ? 'Admin / OSA' : 'Student'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Profile information'),
                subtitle: Text(
                  me.isAdmin
                      ? 'Update your name, email, and profile photo.'
                      : 'Update your name, email, student number, and profile photo.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => store.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
