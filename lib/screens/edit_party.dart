import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../store.dart';

class EditArgs {
  final Party party;
  EditArgs({required this.party});
}

class EditPartyScreen extends StatefulWidget {
  static const routeName = '/edit';
  final EditArgs? args;
  const EditPartyScreen({super.key, this.args});

  @override
  State<EditPartyScreen> createState() => _EditPartyScreenState();
}

class _EditPartyScreenState extends State<EditPartyScreen> {
  final _form = GlobalKey<FormState>();
  bool _isSubmitting = false;
  late String _title;
  late DateTime _time;
  double _fee = 0;
  int? _limit;
  late String _description;
  String? _location;
  String? _posterBase64;

  @override
  void initState() {
    super.initState();
    if (widget.args?.party != null) {
      final p = widget.args!.party;
      _title = p.title;
      _time = p.time;
      _fee = p.fee;
      _limit = p.limit;
      _description = p.description;
      _location = p.location;
      _posterBase64 = p.posterBase64;
    } else {
      _title = '';
      _time = DateTime.now().add(const Duration(days: 1));
      _fee = 0;
      _limit = null;
      _description = '';
      _location = '';
      _posterBase64 = null;
    }
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(withData: true, allowedExtensions: ['png', 'jpg', 'jpeg'], type: FileType.custom);
    if (res != null && res.files.isNotEmpty) {
      final bytes = res.files.first.bytes;
      if (bytes != null) setState(() => _posterBase64 = base64Encode(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<PartyStore>(context, listen: false);
    final isEdit = widget.args?.party != null;
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

    Future<void> pickDateTime() async {
      final d = await showDatePicker(context: context, initialDate: _time, firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (!context.mounted) return;
      if (d != null) {
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_time));
        if (!context.mounted) return;
        if (t != null) {
          setState(() => _time = DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Party' : 'New Party')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              controlContainer(
                child: TextFormField(
                  initialValue: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    filled: false,
                  ),
                  onSaved: (v) => _title = v ?? '',
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: InkWell(
                  onTap: _pickImage,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.upload_file),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _posterBase64 == null ? 'Upload Poster' : 'Change Poster',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_posterBase64 != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.memory(base64Decode(_posterBase64!), fit: BoxFit.cover),
                            ),
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: ListTile(
                  onTap: pickDateTime,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Time: ${DateFormat.yMMMd().add_jm().format(_time)}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: TextFormField(
                  initialValue: _fee == 0 ? '' : _fee.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fee',
                    hintText: '0 = free',
                    suffixText: '€',
                    prefixIcon: Icon(Icons.euro),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => _fee = double.tryParse(v ?? '') ?? 0,
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: TextFormField(
                  initialValue: _limit?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (max attendees)',
                    prefixIcon: Icon(Icons.group),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  onSaved: (v) => _limit = int.tryParse(v ?? ''),
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: TextFormField(
                  initialValue: _location,
                  decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on), filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                  onSaved: (v) => _location = v ?? '',
                ),
              ),
              const SizedBox(height: 8),
              controlContainer(
                child: TextFormField(
                  initialValue: _description,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                  minLines: 6,
                  maxLines: 9,
                  onSaved: (v) => _description = v ?? '',
                ),
              ),
              const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
          );

          if (constraints.maxWidth > 900) {
            return Center(child: content);
          }
          return content;
        },
      ),
      bottomNavigationBar: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bar = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
              onPressed: () async {
                if (_isSubmitting) return;
                if (!_form.currentState!.validate()) return;
                _form.currentState!.save();
                final messenger = ScaffoldMessenger.of(context);
                bool synced = true;
                setState(() => _isSubmitting = true);
                try {
                  if (isEdit) {
                    final old = widget.args!.party;
                    final updated = Party(id: old.id, title: _title, time: _time, fee: _fee, limit: _limit, description: _description, location: _location, posterBase64: _posterBase64, registrations: old.registrations);
                    synced = await store.updateParty(updated);
                  } else {
                    final id = store.nextId();
                    final created = Party(id: id, title: _title, time: _time, fee: _fee, limit: _limit, description: _description, location: _location, posterBase64: _posterBase64);
                    synced = await store.addParty(created);
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                }
                if (!context.mounted) return;
                if (store.cloudEnabled && !synced) {
                  messenger.showSnackBar(const SnackBar(content: Text('Saved locally, but cloud sync failed. Check Firestore rules/config.')));
                }
                if (store.cloudEnabled) {
                  await store.refreshFromCloud();
                  if (!context.mounted) return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(isEdit ? 'Save' : 'Publish'),
                  ),
                ),
              ),
            );

            if (constraints.maxWidth > 900) {
              return Center(child: bar);
            }
            return bar;
          },
        ),
      ),
    );
  }
}
