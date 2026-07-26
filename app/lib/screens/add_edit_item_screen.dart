import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/photo_service.dart';
import '../models/product.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/number_pad_sheet.dart';
import '../widgets/pill_button.dart';
import '../widgets/stepper_control.dart';

/// 2.5 Add / edit item. One form, two modes. Interruptible and forgiving.
class AddEditItemScreen extends ConsumerStatefulWidget {
  const AddEditItemScreen({super.key, this.editProductId, this.prefillName});

  final String? editProductId;
  final String? prefillName;

  bool get isEdit => editProductId != null;

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();

  int _stock = 0;
  int _threshold = 3;
  String? _tag;
  bool _showOnWebsite = true; // inverse of `held`
  String? _imageUrl;
  String? _imageCredit;
  String? _barcode;

  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;

  String? _nameError;
  String? _priceError;
  String? _tagError;

  @override
  void initState() {
    super.initState();
    if (widget.prefillName != null) {
      _name.text = widget.prefillName!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  void _hydrate(Product p) {
    if (_loaded) return;
    _loaded = true;
    _name.text = p.name;
    _description.text = p.description;
    _price.text = (p.priceCents / 100).toStringAsFixed(2);
    _stock = p.stock;
    _threshold = p.lowStockThreshold;
    _tag = p.tag;
    _showOnWebsite = !p.held;
    _imageUrl = p.imageUrl;
    _imageCredit = p.imageCredit;
    _barcode = p.barcode;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Accepts 6.5, 6.50, $6.50, 650c; returns cents or null if unparseable.
  int? _parsePrice(String raw) {
    var s = raw.trim().toLowerCase().replaceAll('\$', '').trim();
    if (s.isEmpty) return null;
    if (s.endsWith('c') && !s.contains('.')) {
      return int.tryParse(s.substring(0, s.length - 1).trim());
    }
    final d = double.tryParse(s);
    if (d == null) return null;
    return (d * 100).round();
  }

  Future<void> _submit() async {
    final cents = _parsePrice(_price.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty
          ? 'Give this item a name so you can find it later.'
          : null;
      if (_price.text.trim().isEmpty) {
        _priceError = 'Put in a price. If it\'s free, put 0.';
      } else if (cents == null) {
        _priceError = 'That price doesn\'t look right. Try something like 6.50.';
      } else {
        _priceError = null;
      }
      _tagError = _tag == null
          ? 'Pick a category so it lands in the right place on the website.'
          : null;
    });

    if (_nameError != null || _priceError != null || _tagError != null) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _saving = true);
    final controller = ref.read(productsProvider.notifier);
    try {
      if (widget.isEdit) {
        await controller.update(
          widget.editProductId!,
          name: _name.text.trim(),
          description: _description.text.trim(),
          priceCents: cents,
          lowStockThreshold: _threshold,
          tag: _tag,
          held: !_showOnWebsite,
          imageUrl: _imageUrl,
          clearImageUrl: _imageUrl == null,
          imageCredit: _imageCredit,
          clearImageCredit: _imageCredit == null,
          barcode: _barcode,
          clearBarcode: _barcode == null,
        );
      } else {
        await controller.add(ProductDraft(
          name: _name.text.trim(),
          description: _description.text.trim(),
          priceCents: cents!,
          initialStock: _stock,
          lowStockThreshold: _threshold,
          tag: _tag!,
          held: !_showOnWebsite,
          imageUrl: _imageUrl,
          imageCredit: _imageCredit,
          barcode: _barcode,
        ));
      }
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEdit
            ? 'Changes saved.'
            : '${_name.text.trim()} added.'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final kn = context.kn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Throw away your changes?',
            style: KnType.title3.copyWith(color: kn.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Throw away', style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;

    // In edit mode, wait for the product then hydrate the form once.
    if (widget.isEdit && !_loaded) {
      final async = ref.watch(productByIdProvider(widget.editProductId!));
      return async.when(
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('$e'))),
        data: (p) {
          if (p == null) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('This item has been removed.')));
          }
          _hydrate(p);
          return _form(kn);
        },
      );
    }
    return _form(kn);
  }

  Widget _form(KnColors kn) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: () async {
              if (await _confirmDiscard() && mounted) context.pop();
            },
            child: Text('Cancel',
                style: KnType.button.copyWith(color: kn.textPrimary)),
          ),
          leadingWidth: 88,
          title: Text(widget.isEdit ? 'Edit item' : 'Add item'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(KnSpace.s4),
                children: [
                  _sectionLabel('What is it?'),
                  _labelRow('Item name', needed: true),
                  _field(_name, error: _nameError, onChanged: (_) {
                    _markDirty();
                    if (_nameError != null) setState(() => _nameError = null);
                  }),
                  const SizedBox(height: KnSpace.s5),
                  _labelRow('A short description', needed: false),
                  _field(_description, maxLines: 3, onChanged: (_) => _markDirty()),
                  _hint('Customers see this on the website.'),

                  const SizedBox(height: KnSpace.s7),
                  _sectionLabel('Numbers'),
                  _labelRow('Price', needed: true),
                  _field(_price,
                      prefix: '\$ ',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      error: _priceError, onChanged: (_) {
                    _markDirty();
                    if (_priceError != null) setState(() => _priceError = null);
                  }),
                  _hint("Type it the way you'd say it: 6.50"),

                  const SizedBox(height: KnSpace.s5),
                  if (!widget.isEdit) ...[
                    _labelRow('How many on the shelf', needed: true),
                    _stepperField(
                      value: _stock,
                      onChange: (v) => setState(() {
                        _stock = v;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: KnSpace.s5),
                  ],
                  _labelRow('Warn me when it drops to', needed: false),
                  _stepperField(
                    value: _threshold,
                    onChange: (v) => setState(() {
                      _threshold = v;
                      _dirty = true;
                    }),
                  ),
                  _hint("We'll also take it off the website at this level, so "
                      "nobody buys what you haven't got."),

                  const SizedBox(height: KnSpace.s7),
                  _sectionLabel('Category'),
                  _pickerRow(kn),
                  if (_tagError != null) _errorText(_tagError!),

                  const SizedBox(height: KnSpace.s7),
                  _sectionLabel('Photo'),
                  _photoRow(kn),

                  if (widget.isEdit) ...[
                    const SizedBox(height: KnSpace.s7),
                    _sectionLabel('On the website'),
                    _switchRow(kn),
                    _hint('Turn this off to keep an item in your list but hide '
                        'it from the website.'),
                    const SizedBox(height: KnSpace.s6),
                    PillButton(
                      'Remove this item',
                      variant: PillVariant.destructive,
                      icon: Icons.delete_outline,
                      onPressed: _removeFromEdit,
                    ),
                  ],
                  const SizedBox(height: KnSpace.s6),
                ],
              ),
            ),
            _footer(kn),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFromEdit() async {
    final kn = context.kn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${_name.text.trim()}?',
            style: KnType.title3.copyWith(color: kn.textPrimary)),
        content: Text(
          'It comes off the website and out of your list. You can put it back '
          'from Settings → Removed items.',
          style: KnType.body.copyWith(color: kn.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(productsProvider.notifier).remove(widget.editProductId!);
      if (mounted) context.pop();
    }
  }

  // --- small builders ---------------------------------------------------

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: KnSpace.s3),
        child: Text(text.toUpperCase(),
            style: KnType.eyebrow.copyWith(color: context.kn.textRed)),
      );

  Widget _labelRow(String label, {required bool needed}) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.only(bottom: KnSpace.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KnType.label.copyWith(color: kn.textPrimary)),
          Text(needed ? 'Needed' : 'Optional',
              style: KnType.caption.copyWith(color: kn.textSecondary)),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? prefix,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? error,
    ValueChanged<String>? onChanged,
  }) {
    final kn = context.kn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: KnType.body.copyWith(color: kn.textPrimary),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: KnType.body.copyWith(color: kn.textPrimary),
            constraints: BoxConstraints(minHeight: maxLines > 1 ? 96 : 52),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: KnSpace.s4, vertical: KnSpace.s3),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnRadius.control),
              borderSide: BorderSide(
                  color: error != null ? kn.textRed : kn.lineControl,
                  width: error != null ? 2 : 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnRadius.control),
              borderSide: BorderSide(
                  color: error != null ? kn.textRed : kn.textPrimary,
                  width: 2),
            ),
          ),
        ),
        if (error != null) _errorText(error),
      ],
    );
  }

  Widget _errorText(String text) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.only(top: KnSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: kn.textRed),
          const SizedBox(width: KnSpace.s1),
          Expanded(
            child: Text(text,
                style: KnType.secondary.copyWith(color: kn.textRed)),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: KnSpace.s2),
        child: Text(text,
            style: KnType.secondary.copyWith(color: context.kn.textSecondary)),
      );

  Widget _stepperField({required int value, required ValueChanged<int> onChange}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: KnSpace.s3, vertical: KnSpace.s2),
        decoration: BoxDecoration(
          border: Border.all(color: context.kn.lineControl, width: 1.5),
          borderRadius: BorderRadius.circular(KnRadius.control),
        ),
        child: StepperControl(
          value: value,
          onDecrement: () => onChange(value > 0 ? value - 1 : 0),
          onIncrement: () => onChange(value + 1),
          onCountLongPress: () async {
            final v = await showNumberPad(context,
                title: 'Set the number', initial: value);
            if (v != null) onChange(v);
          },
        ),
      ),
    );
  }

  Widget _pickerRow(KnColors kn) {
    return InkWell(
      borderRadius: BorderRadius.circular(KnRadius.control),
      onTap: () async {
        final q = _tag == null
            ? ''
            : '?selected=${Uri.encodeQueryComponent(_tag!)}';
        final chosen = await context.push<String>('/category$q');
        if (chosen != null) {
          setState(() {
            _tag = chosen;
            _tagError = null;
            _dirty = true;
          });
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
        decoration: BoxDecoration(
          border: Border.all(color: kn.lineControl, width: 1.5),
          borderRadius: BorderRadius.circular(KnRadius.control),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(_tag ?? 'Choose a category',
                  style: KnType.body.copyWith(
                      color: _tag == null ? kn.textSecondary : kn.textPrimary)),
            ),
            Icon(Icons.chevron_right, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _photoRow(KnColors kn) {
    return InkWell(
      borderRadius: BorderRadius.circular(KnRadius.control),
      onTap: _openPhotoSheet,
      child: Container(
        padding: const EdgeInsets.all(KnSpace.s4),
        decoration: BoxDecoration(
          border: Border.all(color: kn.lineControl, width: 1.5),
          borderRadius: BorderRadius.circular(KnRadius.control),
        ),
        child: Row(
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: kn.textPrimary),
            const SizedBox(width: KnSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_imageUrl == null ? 'Add a photo' : 'Photo added',
                      style: KnType.label.copyWith(color: kn.textPrimary)),
                  Text(
                    _imageUrl == null
                        ? "Or leave it — we'll use the category artwork."
                        : 'Tap to change or remove.',
                    style:
                        KnType.secondary.copyWith(color: kn.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhotoSheet() async {
    final photo = ref.read(photoServiceProvider);
    final kn = context.kn;
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _photoTile(Icons.photo_camera_outlined, 'Take a photo',
                PhotoSource.camera),
            _photoTile(Icons.image_outlined, 'Choose from your photos',
                PhotoSource.library),
            _photoTile(Icons.link, 'Paste a web address', PhotoSource.url),
            _photoTile(
              Icons.auto_awesome_outlined,
              'Find one for me',
              PhotoSource.findForMe,
              subtitle: photo.canFindOnline ? null : 'Needs the internet',
              enabled: photo.canFindOnline,
            ),
            if (_imageUrl != null)
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.delete_outline, color: kn.textRed),
                title: Text('Remove the photo',
                    style: TextStyle(color: kn.textRed)),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final result = await photo.pick(source, query: _name.text.trim());
    // Stub returns null; when the real PhotoService lands this stores the photo.
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _imageUrl = result.imageUrl;
        _imageCredit = result.imageCredit;
        _dirty = true;
      }
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Photos are added by the picker (coming soon). '
            'Category artwork is used for now.'),
      ));
    }
  }

  Widget _photoTile(IconData icon, String label, PhotoSource source,
      {String? subtitle, bool enabled = true}) {
    return ListTile(
      minTileHeight: 56,
      enabled: enabled,
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? () => Navigator.pop(context, source) : null,
    );
  }

  Widget _switchRow(KnColors kn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: Border.all(color: kn.lineHairline),
        borderRadius: BorderRadius.circular(KnRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Show this to customers',
                style: KnType.body.copyWith(color: kn.textPrimary)),
          ),
          Text(_showOnWebsite ? 'ON' : 'OFF',
              style: KnType.caption.copyWith(color: kn.textSecondary)),
          const SizedBox(width: KnSpace.s2),
          Switch(
            value: _showOnWebsite,
            onChanged: (v) => setState(() {
              _showOnWebsite = v;
              _dirty = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _footer(KnColors kn) {
    return Container(
      decoration: BoxDecoration(
        color: kn.surface,
        border: Border(top: BorderSide(color: kn.lineHairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KnSpace.s4),
          child: PillButton(
            widget.isEdit ? 'Save changes' : 'Add item',
            loading: _saving,
            loadingLabel: 'Saving…',
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
