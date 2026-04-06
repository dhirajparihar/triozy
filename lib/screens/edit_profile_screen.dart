import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
  String? _selectedService;

  String? _role;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _photoUrl;
  XFile? _pickedImage;

  static const List<String> _services = [
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpenter',
    'Cleaning',
    'AC Repair',
    'Security',
    'Gardening',
    'Co-rider',
    'Car Taxi',
    'Auto',
    'Delivery',
    'Tailor',
    'Home Salon',
    'Roommate',
    'HelpBuddy',
    'Mechanic',
    'Pest Control',
    'Tile Worker',
    'Rental Rooms',
    'Core Cutting',
    'Property',
    'RO Service',
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
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final data = userSnap.docs.first.data();
        _role = data['role'] as String?;
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        if (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty) {
          _photoUrl = data['photoUrl'];
        }
      }

      // If worker, also load from workers collection
      if (_role == 'worker') {
        final workerQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        final workerSnap = workerQuery.docs.isNotEmpty ? workerQuery.docs.first : null;
        if (workerSnap != null) {
          final wd = workerSnap.data();
          _phoneController.text = wd['phone'] ?? _phoneController.text;
          _locationController.text = wd['location'] ?? '';
          _descriptionController.text = wd['description'] ?? '';
          _experienceController.text = (wd['experience'] ?? 0).toString();
          final skills = List<String>.from(wd['skills'] ?? []);
          final loaded = skills.isNotEmpty ? skills.first : null;
          _selectedService = (loaded != null && _services.contains(loaded)) ? loaded : null;
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
      final photoSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (photoSnap.docs.isNotEmpty) {
        await photoSnap.docs.first.reference
            .set({'photoUrl': downloadUrl}, SetOptions(merge: true));
      }

      // Also update workers collection if worker
      if (_role == 'worker') {
        final workerPhotoSnap = await FirebaseFirestore.instance
            .collection('workers')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (workerPhotoSnap.docs.isNotEmpty) {
          await workerPhotoSnap.docs.first.reference
              .set({'photoUrl': downloadUrl}, SetOptions(merge: true));
        }
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
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final Map<String, dynamic> userUpdate = {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
        if (_role == 'customer') {
          userUpdate['address'] = _addressController.text.trim();
        }
        await userSnap.docs.first.reference.set(userUpdate, SetOptions(merge: true));
      }

      // Save to workers collection if worker
      if (_role == 'worker') {
        final exp = int.tryParse(_experienceController.text.trim()) ?? 0;
        final workerSaveSnap = await FirebaseFirestore.instance
            .collection('workers')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (workerSaveSnap.docs.isNotEmpty) {
          await workerSaveSnap.docs.first.reference.set({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'location': _locationController.text.trim(),
            'description': _descriptionController.text.trim(),
            'experience': exp,
            'skills': _selectedService != null ? [_selectedService!] : [],
            'serviceType': _selectedService ?? '',
          }, SetOptions(merge: true));
        }
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

                      // Service type dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedService,
                        decoration: _dropdownDecoration('Service Type', Icons.work_outline),
                        items: _services
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedService = v),
                        validator: (v) => v == null ? 'Select a service type' : null,
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
