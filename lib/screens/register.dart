import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../store.dart';

class RegisterArgs {
  final String partyId;
  final Party? sharedParty;
  RegisterArgs({required this.partyId, this.sharedParty});
}

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';
  final RegisterArgs args;
  const RegisterScreen({super.key, required this.args});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  String _email = '';
  String _diet = 'No restriction';
  final _options = ['No restriction', 'Vegetarian', 'Vegan', 'No pork', 'No beef', 'No shellfish', 'Halal', 'Kosher', 'Gluten-free', 'Other'];

  IconData _dietIcon(String option) {
    switch (option) {
      case 'No restriction':
        return Icons.check_circle_outline;
      case 'Vegetarian':
      case 'Vegan':
        return Icons.eco_outlined;
      case 'No pork':
      case 'No beef':
      case 'No shellfish':
        return Icons.block_outlined;
      case 'Halal':
      case 'Kosher':
        return Icons.verified_outlined;
      case 'Gluten-free':
        return Icons.spa_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<PartyStore>(context);
    final party = store.byId(widget.args.partyId) ?? widget.args.sharedParty;
    final inputBgColor = Theme.of(context).inputDecorationTheme.fillColor ?? const Color(0xFFF8F1E7);
    const controlRadius = 14.0;
    final controlShadow = [
      const BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.08),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ];

    Widget controlContainer({required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: inputBgColor,
          borderRadius: BorderRadius.circular(controlRadius),
          boxShadow: controlShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(controlRadius),
          child: Material(color: Colors.transparent, child: child),
        ),
      );
    }

    if (party == null) return Scaffold(appBar: AppBar(title: const Text('Register')), body: const Center(child: Text('Party not found')));
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _form,
          child: Column(children: [
            controlContainer(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  filled: false,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                onSaved: (v) => _email = v!.trim(),
              ),
            ),
            const SizedBox(height: 12),
            controlContainer(
              child: DropdownButtonFormField<String>(
                initialValue: _diet,
                dropdownColor: inputBgColor,
                icon: const Icon(Icons.expand_more),
                decoration: const InputDecoration(
                  labelText: 'Dietary Preference',
                  prefixIcon: Icon(Icons.restaurant_menu),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  filled: false,
                ),
                items: _options
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Row(
                          children: [
                            Icon(_dietIcon(o), size: 18),
                            const SizedBox(width: 8),
                            Text(o),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _diet = v ?? _diet),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              var currentParty = store.byId(widget.args.partyId) ?? widget.args.sharedParty;
              if (currentParty == null) {
                messenger.showSnackBar(const SnackBar(content: Text('Party not found')));
                return;
              }

              if (store.byId(widget.args.partyId) == null) {
                await store.ensurePartyExists(currentParty);
                if (!mounted) return;
                currentParty = store.byId(widget.args.partyId) ?? currentParty;
              }

              if (!_form.currentState!.validate()) return;
              _form.currentState!.save();
              // check duplicate
              if (currentParty.registrations.any((r) => r.email.toLowerCase() == _email.toLowerCase())) {
                messenger.showSnackBar(const SnackBar(content: Text('Already registered')));
                return;
              }
              if (currentParty.limit != null && currentParty.registrations.length >= currentParty.limit!) {
                messenger.showSnackBar(const SnackBar(content: Text('Party is full')));
                return;
              }
              final ok = await store.register(currentParty.id, _email, _diet);
              if (!mounted) return;
              if (ok) {
                if (store.cloudEnabled) {
                  await store.refreshFromCloud();
                  if (!mounted) return;
                }
                if (store.cloudEnabled && store.lastSyncError != null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Registration saved locally, but cloud sync failed.')));
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('Registration successful')));
                }
                navigator.pop();
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('Registration failed')));
              }
            }, child: const Text('Register')),
          ]),
        ),
      ),
    );
  }
}
