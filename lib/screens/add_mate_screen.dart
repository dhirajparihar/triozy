import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mate_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AddMateScreen extends StatefulWidget {
  final MateType initialType;
  final MateModel? mateToEdit;
  const AddMateScreen({super.key, this.initialType = MateType.roommate, this.mateToEdit});

  @override
  State<AddMateScreen> createState() => _AddMateScreenState();
}

class _AddMateScreenState extends State<AddMateScreen> {
  final _formKey = GlobalKey<FormState>();

  late MateType _selectedType;
  bool _isLoading = false;
  bool _isLocating = false;

  // Common
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Roommate
  final _budgetCtrl = TextEditingController();
  String _preferredGender = 'Any';
  final List<String> _lifestyle = [];

  // Helpmate
  final List<String> _helpTypes = [];
  bool _available = true;

  // Ridemate
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String _frequency = 'Daily';
  String _vehicleType = 'Bike';

  double? _latitude;
  double? _longitude;

  static const _genderOptions = ['Any', 'Male', 'Female'];
  static const _lifestyleOptions = [
    'Non-smoker', 'Vegetarian', 'Early riser', 'Night owl',
    'Pet-friendly', 'Students only', 'Working professional',
  ];
  static const _helpTypeOptions = [
    'Errands', 'Emergency', 'Medical', 'Moving help',
    'Companionship', 'Tech help', 'Grocery', 'Other',
  ];
  static const _frequencyOptions = ['Daily', 'Weekdays', 'Weekends', 'Once'];
  static const _vehicleOptions = ['Bike', 'Scooty', 'Car'];

  static const _typeColors = {
    MateType.roommate: AppColors.primary,
    MateType.helpmate: AppColors.secondary,
    MateType.ridemate: AppColors.tertiary,
  };

  static const _typeIcons = {
    MateType.roommate: Icons.people_alt_rounded,
    MateType.helpmate: Icons.handshake_rounded,
    MateType.ridemate: Icons.directions_bike_rounded,
  };

  Color get _accentColor => _typeColors[_selectedType]!;

  @override
  void initState() {
    super.initState();
    final edit = widget.mateToEdit;
    _selectedType = edit?.type ?? widget.initialType;

    if (edit != null) {
      _phoneCtrl.text = edit.phone;
      _locationCtrl.text = edit.location;
      _descCtrl.text = edit.description;
      _latitude = edit.latitude;
      _longitude = edit.longitude;
      // Roommate
      _budgetCtrl.text = edit.budget ?? '';
      _preferredGender = edit.preferredGender ?? 'Any';
      _lifestyle
        ..clear()
        ..addAll(edit.lifestyle);
      // Helpmate
      _helpTypes
        ..clear()
        ..addAll(edit.helpTypes);
      _available = edit.available;
      // Ridemate
      _fromCtrl.text = edit.fromLocation ?? '';
      _toCtrl.text = edit.toLocation ?? '';
      _timeCtrl.text = edit.departureTime ?? '';
      _frequency = edit.frequency ?? 'Daily';
      _vehicleType = edit.vehicleType ?? 'Bike';
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc = context.read<LocationProvider>();
        if (loc.address.isNotEmpty && _locationCtrl.text.isEmpty) {
          _locationCtrl.text = loc.address;
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final svc = LocationService();
      final pos = await svc.getCurrentPosition();
      final addr = await svc.getAddressFromCoordinates(pos.latitude, pos.longitude);
      setState(() {
        _locationCtrl.text = addr;
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null && mounted) {
      setState(() => _timeCtrl.text = picked.format(context));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final isEdit = widget.mateToEdit != null;

      final mate = MateModel(
        id: widget.mateToEdit?.id ?? const Uuid().v4(),
        type: _selectedType,
        userId: widget.mateToEdit?.userId ?? user.uid,
        userName: widget.mateToEdit?.userName ?? user.displayName ?? 'User',
        userPhoto: widget.mateToEdit?.userPhoto ?? user.photoURL ?? '',
        phone: _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        description: _descCtrl.text.trim(),
        createdAt: widget.mateToEdit?.createdAt,
        // Roommate
        budget: _selectedType == MateType.roommate ? _budgetCtrl.text.trim() : null,
        preferredGender: _selectedType == MateType.roommate ? _preferredGender : null,
        lifestyle: _selectedType == MateType.roommate ? List.from(_lifestyle) : [],
        // Helpmate
        helpTypes: _selectedType == MateType.helpmate ? List.from(_helpTypes) : [],
        available: _selectedType == MateType.helpmate ? _available : true,
        // Ridemate
        fromLocation: _selectedType == MateType.ridemate ? _fromCtrl.text.trim() : null,
        toLocation: _selectedType == MateType.ridemate ? _toCtrl.text.trim() : null,
        departureTime: _selectedType == MateType.ridemate ? _timeCtrl.text.trim() : null,
        frequency: _selectedType == MateType.ridemate ? _frequency : null,
        vehicleType: _selectedType == MateType.ridemate ? _vehicleType : null,
      );

      if (isEdit) {
        await db.updateMate(mate);
      } else {
        await db.postMate(mate);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? '${_selectedType.label} post updated' : '${_selectedType.label} post published'),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.mateToEdit != null ? 'update' : 'post'}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mateToEdit != null ? 'Edit ${widget.mateToEdit!.type.label}' : 'Post a Mate',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Type Selector ──────────────────────────
            _SectionLabel(label: 'What are you looking for?'),
            const SizedBox(height: 10),
            _TypeSelector(
              selected: _selectedType,
              colors: _typeColors,
              icons: _typeIcons,
              onChanged: (t) => setState(() => _selectedType = t),
            ),
            const SizedBox(height: 24),

            // ── Common Fields ──────────────────────────
            _SectionLabel(label: 'Contact & Location'),
            const SizedBox(height: 10),
            _Field(
              controller: _phoneCtrl,
              label: 'Phone Number',
              hint: 'Your contact number',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              accentColor: _accentColor,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _locationCtrl,
              label: 'Location / Area',
              hint: 'Your area or neighbourhood',
              icon: Icons.location_on_rounded,
              accentColor: _accentColor,
              suffix: _isLocating
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : IconButton(
                      icon: Icon(Icons.my_location_rounded, color: _accentColor, size: 20),
                      onPressed: _detectLocation,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
            ),
            const SizedBox(height: 24),

            // ── Type-Specific Fields ───────────────────
            ..._buildTypeFields(),

            // ── Description ───────────────────────────
            _SectionLabel(label: 'About You (optional)'),
            const SizedBox(height: 10),
            _Field(
              controller: _descCtrl,
              label: 'Description',
              hint: 'A short note about yourself or what you\'re looking for...',
              icon: Icons.notes_rounded,
              maxLines: 3,
              accentColor: _accentColor,
            ),
            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.mateToEdit != null
                            ? 'Update ${_selectedType.label}'
                            : 'Post ${_selectedType.label}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeFields() {
    switch (_selectedType) {
      case MateType.roommate:
        return _roommateFields();
      case MateType.helpmate:
        return _helpmateFields();
      case MateType.ridemate:
        return _ridemateFields();
    }
  }

  List<Widget> _roommateFields() => [
    _SectionLabel(label: 'Room Details'),
    const SizedBox(height: 10),
    _Field(
      controller: _budgetCtrl,
      label: 'Monthly Budget',
      hint: 'e.g. ₹5,000 – ₹8,000',
      icon: Icons.currency_rupee_rounded,
      keyboardType: TextInputType.text,
      accentColor: _accentColor,
    ),
    const SizedBox(height: 16),
    _SectionLabel(label: 'Preferred Roommate Gender'),
    const SizedBox(height: 10),
    _OptionChips(
      options: _genderOptions,
      selected: [_preferredGender],
      singleSelect: true,
      accentColor: _accentColor,
      onToggle: (v) => setState(() => _preferredGender = v),
    ),
    const SizedBox(height: 16),
    _SectionLabel(label: 'Lifestyle Preferences'),
    const SizedBox(height: 10),
    _OptionChips(
      options: _lifestyleOptions,
      selected: _lifestyle,
      accentColor: _accentColor,
      onToggle: (v) => setState(() {
        _lifestyle.contains(v) ? _lifestyle.remove(v) : _lifestyle.add(v);
      }),
    ),
    const SizedBox(height: 24),
  ];

  List<Widget> _helpmateFields() => [
    _SectionLabel(label: 'I can help with'),
    const SizedBox(height: 10),
    _OptionChips(
      options: _helpTypeOptions,
      selected: _helpTypes,
      accentColor: _accentColor,
      onToggle: (v) => setState(() {
        _helpTypes.contains(v) ? _helpTypes.remove(v) : _helpTypes.add(v);
      }),
    ),
    const SizedBox(height: 16),
    _ToggleRow(
      label: 'Available Right Now',
      value: _available,
      accentColor: _accentColor,
      onChanged: (v) => setState(() => _available = v),
    ),
    const SizedBox(height: 24),
  ];

  List<Widget> _ridemateFields() => [
    _SectionLabel(label: 'Route'),
    const SizedBox(height: 10),
    _Field(
      controller: _fromCtrl,
      label: 'From',
      hint: 'Starting point',
      icon: Icons.trip_origin_rounded,
      accentColor: _accentColor,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Starting point is required' : null,
    ),
    const SizedBox(height: 12),
    _Field(
      controller: _toCtrl,
      label: 'To',
      hint: 'Destination',
      icon: Icons.location_on_rounded,
      accentColor: _accentColor,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Destination is required' : null,
    ),
    const SizedBox(height: 16),
    _SectionLabel(label: 'Departure Time'),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: _pickTime,
      child: AbsorbPointer(
        child: _Field(
          controller: _timeCtrl,
          label: 'Time',
          hint: 'Tap to pick time',
          icon: Icons.schedule_rounded,
          accentColor: _accentColor,
        ),
      ),
    ),
    const SizedBox(height: 16),
    _SectionLabel(label: 'Frequency'),
    const SizedBox(height: 10),
    _OptionChips(
      options: _frequencyOptions,
      selected: [_frequency],
      singleSelect: true,
      accentColor: _accentColor,
      onToggle: (v) => setState(() => _frequency = v),
    ),
    const SizedBox(height: 16),
    _SectionLabel(label: 'Vehicle'),
    const SizedBox(height: 10),
    _OptionChips(
      options: _vehicleOptions,
      selected: [_vehicleType],
      singleSelect: true,
      accentColor: _accentColor,
      onToggle: (v) => setState(() => _vehicleType = v),
    ),
    const SizedBox(height: 24),
  ];
}

// ── Reusable form widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTheme.body(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType keyboardType;
  final int maxLines;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: AppTheme.body(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTheme.body(fontSize: 14, color: AppColors.slate400),
        labelStyle: AppTheme.label(fontSize: 13, color: AppColors.slate500),
        prefixIcon: Icon(icon, size: 18, color: AppColors.slate400),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final MateType selected;
  final Map<MateType, Color> colors;
  final Map<MateType, IconData> icons;
  final ValueChanged<MateType> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.colors,
    required this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MateType.values.map((type) {
        final isSelected = selected == type;
        final color = colors[type]!;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: type != MateType.ridemate ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    icons[type]!,
                    size: 24,
                    color: isSelected ? Colors.white : AppColors.slate400,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OptionChips extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final Color accentColor;
  final bool singleSelect;
  final ValueChanged<String> onToggle;

  const _OptionChips({
    required this.options,
    required this.selected,
    required this.accentColor,
    required this.onToggle,
    this.singleSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accentColor : AppColors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Text(
              opt,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.slate500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accentColor : AppColors.slate400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accentColor,
          ),
        ],
      ),
    );
  }
}
