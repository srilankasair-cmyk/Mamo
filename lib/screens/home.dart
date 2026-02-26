import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../store.dart';
import 'edit_party.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PartyStore>(builder: (context, store, _) {
      final parties = store.parties..sort((a, b) => a.time.compareTo(b.time));
      final count = parties.length;
      final headerText = count == 1 ? '1 Party' : '$count PARTIES';
      if (store.isInitialLoading && parties.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              headerText,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
          ),
        ),
        if (!store.cloudEnabled || store.lastSyncError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                !store.cloudEnabled
                    ? 'Cloud sync is disabled. Configure Firebase Secrets in GitHub Actions to share data across devices.'
                    : '${store.lastSyncError!}${store.cloudProjectId != null ? ' (project: ${store.cloudProjectId})' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (store.isSyncing)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final cross = constraints.maxWidth > 600 ? 2 : 1;
            // For single-column layout use a ListView so cards size to content
            if (cross == 1) {
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: parties.length,
                itemBuilder: (context, i) {
                  final p = parties[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _PartyCard(p: p, onTap: () => Navigator.pushNamed(context, '/party/${p.id}')),
                  );
                },
              );
            }

            // compute tile width and a safe childAspectRatio so cards have enough
            // height for the image + text on medium/tablet sizes
            final horizontalPadding = 16.0; // container padding + approximate spacing
            final available = constraints.maxWidth - horizontalPadding;
            final tileWidth = available / cross - 8; // account for grid spacing
            final imageH = tileWidth * 9 / 16; // AspectRatio 16:9 image height
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final contentMin = 140.0 + (textScale - 1.0) * 40.0; // reserve more space on tablet/large text
            final tileH = imageH + contentMin;
            var childAspect = tileWidth / tileH;
            // clamp to reasonable bounds
            if (childAspect < 0.8) childAspect = 0.8;
            if (childAspect > 1.45) childAspect = 1.45;

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, childAspectRatio: childAspect, mainAxisSpacing: 8, crossAxisSpacing: 8),
              padding: const EdgeInsets.all(8),
              itemCount: parties.length,
              itemBuilder: (context, i) {
                final p = parties[i];
                return _PartyCard(p: p, onTap: () => Navigator.pushNamed(context, '/party/${p.id}'));
              },
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
            child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, EditPartyScreen.routeName, arguments: null),
              tooltip: 'Create',
              child: const Icon(Icons.add),
            ),
          ),
        )
      ]);
    });
  }
}

class _PartyCard extends StatelessWidget {
  final Party p;
  final VoidCallback onTap;
  const _PartyCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm().format(p.time);
    return Stack(children: [
      Card(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: p.posterBase64 != null
                  ? Image.memory(base64Decode(p.posterBase64!), fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image, size: 48))),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(date, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                if (p.location != null && p.location!.isNotEmpty) ...[
                  Text(p.location!, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                ],
                Text('${p.registrations.length}/${p.limit ?? '∞'} attending', style: Theme.of(context).textTheme.bodySmall),
              ]),
            )
          ]),
        ),
      ),
      Positioned(
        right: 6,
        top: 6,
            child: Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            onSelected: (v) async {
              final store = Provider.of<PartyStore>(context, listen: false);
              if (v == 'edit') {
                await Navigator.pushNamed(context, EditPartyScreen.routeName, arguments: EditArgs(party: p));
                return;
              } else if (v == 'share') {
                final link = Uri.base.replace(fragment: '/party/${p.id}').toString();
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                return;
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete?'),
                    content: const Text('Are you sure you want to delete this party?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))
                    ],
                  ),
                );
                if (ok == true) {
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  final synced = await store.deleteParty(p.id);
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();
                  if (store.cloudEnabled && !synced) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted locally, but cloud sync failed.')));
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('Share link')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.45), shape: BoxShape.circle),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            ),
          ),
        ),
      )
    ]);
  }
}
