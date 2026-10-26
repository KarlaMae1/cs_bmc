import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: Text(['Dashboard', 'Records', 'Profile'][_tab]),
      ),
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
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Records'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
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

    final upcoming = recs
        .where((r) => r.status != 'Completed' && r.dutyDate != null)
        .toList()
      ..sort((a, b) => a.dutyDate!.compareTo(b.dutyDate!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Kumusta, ${me.name}!',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(me.isAdmin ? 'Admin / OSA' : 'Student',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatTile('Active', '$pending', Icons.pending_actions, Colors.orange),
            const SizedBox(width: 10),
            _StatTile('Tapos na', '$done', Icons.check_circle, Colors.green),
            const SizedBox(width: 10),
            _StatTile('Natitirang oras', hoursText(remaining), Icons.timer,
                Theme.of(context).colorScheme.primary),
          ],
        ),
        const SizedBox(height: 24),
        Text('Susunod na duty',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Walang naka-schedule na duty.'),
            ),
          )
        else
          ...upcoming.take(5).map((r) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(me.isAdmin
                      ? store.studentName(r.studentId)
                      : r.violation),
                  subtitle: Text(
                      '${dateFmt.format(r.dutyDate!)}${r.dutyTime.isEmpty ? '' : ' • ${r.dutyTime}'}\n${r.ticketNo}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecordDetailScreen(recordId: r.id)),
                  ),
                ),
              )),
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
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11)),
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
                  ? 'Hanapin ang student, ticket o violation'
                  : 'Hanapin ang ticket o violation',
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
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    store.visibleRecords.isEmpty
                        ? 'Wala pang record.'
                        : 'Walang tumugma sa hinahanap.',
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
                      showStudent: me.isAdmin,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                RecordDetailScreen(recordId: r.id)),
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
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final me = store.current!;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: cs.primaryContainer,
            child: Text(
              me.name.isEmpty ? '?' : me.name[0].toUpperCase(),
              style: TextStyle(fontSize: 36, color: cs.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(me.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(me.email)),
              ListTile(
                  leading: const Icon(Icons.shield),
                  title: const Text('Role'),
                  subtitle: Text(me.isAdmin ? 'Admin / OSA' : 'Student')),
              if (!me.isAdmin)
                ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Student number'),
                    subtitle: Text(me.studentNo)),
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
