import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_categories.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Customer-only
  final _addressController = TextEditingController();

  // Worker-only
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceController = TextEditingController();
  List<String> _selectedServices = [];

  String? _role;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _photoUrl;
  XFile? _pickedImage;

  static final List<String> _services = [
    ...AppCategories.all,
    // Keep legacy options for old profiles.
    'Delivery',
    'Pest Control',
    'Plumbing',
    'Electrical',
    'Painting',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _nameController.text = user.displayName ?? '';
    _photoUrl = user.photoURL;

    try {
      // Load from users collection
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        final fallback = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) {
          userDoc = fallback.docs.first;
        }
      }

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _role = data['role'] as String?;
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        if (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty) {
          _photoUrl = data['photoUrl'];
        }
      }

      // If worker, also load from workers collection
      if (_role == 'worker') {
        var workerDoc = await FirebaseFirestore.instance
            .collection('workers')
            .doc(user.uid)
            .get();
        if (!workerDoc.exists) {
          final fallback = await FirebaseFirestore.instance
              .collection('workers')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (fallback.docs.isNotEmpty) {
            workerDoc = fallback.docs.first;
          }
        }
        if (workerDoc.exists) {
          final wd = workerDoc.data()!;
          _phoneController.text = wd['phone'] ?? _phoneController.text;
          _locationController.text = wd['location'] ?? '';
          _descriptionController.text = wd['description'] ?? '';
          _experienceController.text = (wd['experience'] ?? 0).toString();
          final skills = List<String>.from(wd['skills'] ?? []);
          _selectedServices = skills.where(_services.contains).toList();
          if (wd['photoUrl'] != null && (wd['photoUrl'] as String).isNotEmpty) {
            _photoUrl = wd['photoUrl'];
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _pickedImage = image;
      _uploadingPhoto = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos/${user.uid}.jpg');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = ref.putFile(File(image.path));
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);

      // Update users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'photoUrl': downloadUrl,
      }, SetOptions(merge: true));

      // Also update workers collection if worker
      if (_role == 'worker') {
        await FirebaseFirestore.instance.collection('workers').doc(user.uid).set({
          'uid': user.uid,
          'photoUrl': downloadUrl,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() => _photoUrl = downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated!'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.updateDisplayName(_nameController.text.trim());

      // Save to users collection
      final Map<String, dynamic> userUpdate = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      if (_role == 'customer') {
        userUpdate['address'] = _addressController.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userUpdate, SetOptions(merge: true));

      // Save to workers collection if worker
      if (_role == 'worker') {
        final exp = int.tryParse(_experienceController.text.trim()) ?? 0;
        await FirebaseFirestore.instance.collection('workers').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
          'experience': exp,
          'skills': _selectedServices,
          'serviceType': _selectedServices.isNotEmpty ? _selectedServices.first : '',
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAvatar() {
    ImageProvider? imageProvider;
    if (_pickedImage != null && !kIsWeb) {
      imageProvider = FileImage(File(_pickedImage!.path));
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_photoUrl!);
    }

    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: _uploadingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tap to change photo',
                        style: AppTheme.body(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Common Fields ──
                    _sectionLabel('Personal Info'),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhoneNumber,
                    ),
                    const SizedBox(height: 16),

                    // ── Customer-only ──
                    if (_role == 'customer') ...[
                      _buildField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Worker-only ──
                    if (_role == 'worker') ...[
                      const SizedBox(height: 8),
                      _sectionLabel('Work Details'),
                      const SizedBox(height: 12),

                      // Service type multi-select
                      FormField<List<String>>(
                        initialValue: _selectedServices,
                        validator: (_) => _selectedServices.isEmpty
                            ? 'Select at least one service'
                            : null,
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _ServicePickerSheet(
                                    services: _services,
                                    selected: List.of(_selectedServices),
                                    onChanged: (updated) =>
                                        setState(() => _selectedServices = updated),
                                  ),
                                );
                                field.didChange(_selectedServices);
                              },
                              child: InputDecorator(
                                decoration: _dropdownDecoration(
                                  'Service Types (tap to select)',
                                  Icons.work_outline,
                                ).copyWith(
                                  errorText: field.errorText,
                                  suffixIcon: const Icon(Icons.expand_more),
                                ),
                                child: _selectedServices.isEmpty
                                    ? Text(
                                        'Select services…',
                                        style: AppTheme.body(
                                            fontSize: 14,
                                            color: AppColors.outline),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: _selectedServices
                                            .map((s) => Chip(
                                                  label: Text(s,
                                                      style: AppTheme.body(
                                                          fontSize: 12)),
                                                  backgroundColor:
                                                      AppColors.primary
                                                          .withValues(alpha: 0.1),
                                                  side: const BorderSide(
                                                      color: AppColors.primary,
                                                      width: 0.8),
                                                  deleteIcon: const Icon(
                                                      Icons.close,
                                                      size: 14),
                                                  onDeleted: () => setState(
                                                      () => _selectedServices
                                                          .remove(s)),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                ))
                                            .toList(),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildField(
                        controller: _experienceController,
                        label: 'Years of Experience',
                        icon: Icons.history,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildField(
                        controller: _locationController,
                        label: 'Work Location / Area',
                        icon: Icons.near_me_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildField(
                        controller: _descriptionController,
                        label: 'About / Description',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: AppTheme.body(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTheme.headline(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.body(fontSize: 14, color: AppColors.outline),
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTheme.body(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.body(fontSize: 14, color: AppColors.outline),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: const Icon(Icons.person, size: 56, color: AppColors.outline),
    );
  }
}

class _ServicePickerSheet extends StatefulWidget {
  final List<String> services;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _ServicePickerSheet({
    required this.services,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Services',
                    style: AppTheme.headline(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onChanged(_selected);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: widget.services.length,
                itemBuilder: (_, i) {
                  final s = widget.services[i];
                  final checked = _selected.contains(s);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(s, style: AppTheme.body(fontSize: 15)),
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged: (_) => setState(() {
                      checked ? _selected.remove(s) : _selected.add(s);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
