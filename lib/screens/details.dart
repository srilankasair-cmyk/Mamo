import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../store.dart';
import '../models.dart';
import 'register.dart';
import 'edit_party.dart';

class PartyDetailsScreen extends StatelessWidget {
  final String partyId;
  final Party? sharedParty;
  const PartyDetailsScreen({super.key, required this.partyId, this.sharedParty});

  @override
  Widget build(BuildContext context) {
    return Consumer<PartyStore>(builder: (context, store, _) {
      final p = store.byId(partyId) ?? sharedParty;
      if (p == null) return Scaffold(appBar: AppBar(title: const Text('Not found')), body: const Center(child: Text('Party not found')));
      final date = DateFormat.yMMMd().add_jm().format(p.time);
      final infoStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
      final imageHeight = (MediaQuery.of(context).size.width * 3 / 4).clamp(240.0, 400.0).toDouble();
      const emojiFallback = ['Apple Color Emoji', 'Noto Color Emoji', 'Segoe UI Emoji'];
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: imageHeight,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.45), shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
              title: Text(p.title, style: const TextStyle(fontFamilyFallback: emojiFallback)),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: p.posterBase64 != null
                    ? Image.memory(base64Decode(p.posterBase64!), fit: BoxFit.cover)
                    : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image, size: 80))),
              ),
              actions: [
                PopupMenuButton<String>(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.45), shape: BoxShape.circle),
                      child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    ),
                    onSelected: (v) async {
                      if (v == 'share') {
                        final payload = Uri.encodeComponent(base64Url.encode(utf8.encode(jsonEncode(p.toJson()))));
                        final link = Uri.base.replace(fragment: '/party/${p.id}?d=$payload').toString();
                        await Clipboard.setData(ClipboardData(text: link));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                        return;
                      }
                      if (v == 'edit') {
                        await Navigator.pushNamed(context, EditPartyScreen.routeName, arguments: EditArgs(party: p));
                        return;
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete?'),
                            content: const Text('Are you sure you want to delete this party?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))
                            ],
                          ),
                        );
                        if (ok == true) {
                          await store.deleteParty(p.id);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                          const PopupMenuItem(value: 'share', child: Text('Share link')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ])
              ],
            ),
            SliverToBoxAdapter(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamilyFallback: emojiFallback),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (p.location != null && p.location!.isNotEmpty) Text('Location: ${p.location}', style: infoStyle),
                  const SizedBox(height: 6),
                  Text(date, style: infoStyle),
                  const SizedBox(height: 8),
                  Text('Fee: ${p.fee == 0 ? 'Free' : '€${p.fee.toStringAsFixed(2)}'}'),
                  const SizedBox(height: 8),
                  Text('Capacity: ${p.registrations.length}/${p.limit ?? '∞'}'),
                  const SizedBox(height: 12),
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Card(
                    clipBehavior: Clip.hardEdge,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 120),
                        child: Text(p.description.isNotEmpty ? p.description : 'No description provided.'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Registrations', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  ...p.registrations.map((r) => ListTile(title: Text(r.email), subtitle: Text(r.diet))),
                  const SizedBox(height: 12),
                ]),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, RegisterScreen.routeName, arguments: RegisterArgs(partyId: p.id, sharedParty: p)),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Register'),
              ),
            ),
          ),
        ),
      );
    });
  }
}
