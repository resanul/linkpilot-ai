import 'package:flutter/material.dart';

void main() => runApp(const LinkPilotApp());

const blue = Color(0xFF2563EB);
const ink = Color(0xFF14213D);
const canvas = Color(0xFFF4F6FA);

class LinkPilotApp extends StatelessWidget {
  const LinkPilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'LinkPilot AI',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: blue)),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  bool adminMode = false;
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = adminMode
      ? [const AdminHome(), const LicenseManager(), const AdminCustomers(), const AdminStaff()]
      : [const UserHome(), const UserHistory(), const UserSettings()];
    return Scaffold(
      appBar: AppBar(backgroundColor: canvas, title: const Text('⚡ LinkPilot AI',
        style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [Padding(padding: const EdgeInsets.only(right: 10),
          child: SegmentedButton<bool>(showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('User'), icon: Icon(Icons.person_outline)),
              ButtonSegment(value: true, label: Text('Admin'), icon: Icon(Icons.shield_outlined)),
            ],
            selected: {adminMode},
            onSelectionChanged: (v) => setState(() { adminMode = v.first; tab = 0; }))) ]),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: adminMode ? const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.key_outlined), label: 'Licenses'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Customers'),
        ] : const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ]),
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [ink, blue])),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR LINKEDIN WORKSPACE', style: TextStyle(color: Colors.white70, fontSize: 11)),
        SizedBox(height: 12), Text('Build your presence\\nwith AI.',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 16), Text('Daily schedule · 8:00 PM Dhaka',
          style: TextStyle(color: Colors.white))
      ])),
    const SizedBox(height: 18),
    const Row(children: [Expanded(child: Metric('Published', '12', Icons.send)),
      SizedBox(width: 10), Expanded(child: Metric('Pending', '3', Icons.hourglass_top))]),
    const SizedBox(height: 20), const Section('LinkedIn account'),
    Card(child: ListTile(leading: const Icon(Icons.business_center, color: Color(0xFF0A66C2)),
      title: const Text('Connect your LinkedIn'),
      subtitle: const Text('One personal profile · Official OAuth'),
      trailing: FilledButton(onPressed: () {}, child: const Text('Connect')))),
    const Section('Publishing mode'),
    Card(child: SwitchListTile(value: false, onChanged: (_) {},
      title: const Text('Automatic publishing'),
      subtitle: const Text('Demo control — backend connection required'))),
  ]);
}
class UserHistory extends StatelessWidget {
  const UserHistory({super.key});
  @override Widget build(BuildContext context) => const EmptyPage(
    title: 'Post history', detail: 'Published posts, drafts and pending approvals will appear here.',
    icon: Icons.history);
}
class UserSettings extends StatelessWidget {
  const UserSettings({super.key});
  @override Widget build(BuildContext context) => const EmptyPage(
    title: 'Settings', detail: 'License status, cloud backup, publishing time and privacy settings.',
    icon: Icons.settings);
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      color: ink, borderRadius: BorderRadius.circular(22)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ADMIN CONTROL CENTER', style: TextStyle(color: Colors.white70, fontSize: 11)),
        SizedBox(height: 10), Text('Manage your\\nLinkPilot business.',
          style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
        SizedBox(height: 8), Text('Commercial edition · Owner dashboard',
          style: TextStyle(color: Colors.white70))
      ])),
    const SizedBox(height: 18),
    const Row(children: [Expanded(child: Metric('Customers', '—', Icons.people)),
      SizedBox(width: 10), Expanded(child: Metric('Active licenses', '—', Icons.key))]),
    const SizedBox(height: 10),
    const Row(children: [Expanded(child: Metric('Assigned', '—', Icons.assignment_turned_in)),
      SizedBox(width: 10), Expanded(child: Metric('Posts', '—', Icons.article))]),
    const SizedBox(height: 20), const Section('Quick actions'),
    const ActionRow(Icons.add_card, 'Create a license', 'Generate a customer activation key'),
    const ActionRow(Icons.manage_accounts, 'Manage customers', 'Review account and subscription status'),
    const ActionRow(Icons.block, 'Revoke a license', 'Deactivate a key'),
    const SizedBox(height: 10),
    const Text('Metrics are placeholders until the admin API is connected.',
      style: TextStyle(color: Colors.black54, fontSize: 12))
  ]);
}

class LicenseManager extends StatefulWidget {
  const LicenseManager({super.key});
  @override State<LicenseManager> createState() => _LicenseManagerState();
}
class _LicenseManagerState extends State<LicenseManager> {
  String plan = 'standard';
  String duration = 'monthly';
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('License manager', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6), const Text('Create, review and revoke customer licenses.'),
    const SizedBox(height: 18),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Generate new license', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 12), const Text('Subscription plan'),
        DropdownButtonFormField<String>(value: plan, items: const [
          DropdownMenuItem(value: 'standard', child: Text('Standard')),
          DropdownMenuItem(value: 'pro', child: Text('Pro')),
          DropdownMenuItem(value: 'business', child: Text('Business')),
        ], onChanged: (v) => setState(() => plan = v ?? 'standard')),
        const SizedBox(height: 10), const Text('Validity'),
        DropdownButtonFormField<String>(value: duration, items: const [
          DropdownMenuItem(value: 'monthly', child: Text('Monthly · 30 days')),
          DropdownMenuItem(value: 'yearly', child: Text('Yearly · 365 days')),
          DropdownMenuItem(value: 'lifetime', child: Text('Lifetime · no expiry')),
        ], onChanged: (v) => setState(() => duration = v ?? 'monthly')),
        const SizedBox(height: 16), SizedBox(width: double.infinity,
          child: FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect POST /admin/licenses to issue live keys.'))),
            icon: const Icon(Icons.add), label: const Text('Generate license')))
      ]))),
    const SizedBox(height: 18), const Section('Recent licenses'),
    const EmptyPage(title: 'No live license data connected',
      detail: 'Generated keys, plan, expiry, assigned customer and status will appear here.',
      icon: Icons.key)
  ]);
}

class AdminStaff extends StatelessWidget {
  const AdminStaff({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Staff administrators', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6), const Text('Only Super Admin can add or revoke staff access.'),
    const SizedBox(height: 18),
    Card(child: ListTile(leading: const Icon(Icons.person_add_alt_1, color: blue),
      title: const Text('Add staff administrator'),
      subtitle: const Text('Invite by Google account email'),
      trailing: const Icon(Icons.chevron_right))),
    const SizedBox(height: 12),
    const EmptyPage(title: 'No staff records loaded',
      detail: 'Connect GET /admin/staff and POST /admin/staff to manage staff access.',
      icon: Icons.admin_panel_settings)
  ]);
}

class AdminCustomers extends StatelessWidget {
  const AdminCustomers({super.key});
  @override Widget build(BuildContext context) => const EmptyPage(
    title: 'Customers', detail: 'Customer accounts and subscription status will appear here.',
    icon: Icons.people);
}

class Metric extends StatelessWidget {
  final String title, value; final IconData icon;
  const Metric(this.title, this.value, this.icon, {super.key});
  @override Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: blue), const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12))
    ])));
}
class Section extends StatelessWidget {
  final String title; const Section(this.title, {super.key});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));
}
class ActionRow extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const ActionRow(this.icon, this.title, this.subtitle, {super.key});
  @override Widget build(BuildContext context) => Card(child: ListTile(
    leading: Icon(icon, color: blue), title: Text(title), subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right)));
}
class EmptyPage extends StatelessWidget {
  final String title, detail; final IconData icon;
  const EmptyPage({required this.title, required this.detail, required this.icon, super.key});
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 44, color: blue), const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), Text(detail, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54))
    ])));
}
