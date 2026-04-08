import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'policy_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'main_shell.dart';
import '../constants/app_categories.dart';

class WorkerSetupScreen extends StatefulWidget {
  const WorkerSetupScreen({super.key});

  @override
  State<WorkerSetupScreen> createState() => _WorkerSetupScreenState();
}

class _WorkerSetupScreenState extends State<WorkerSetupScreen> {
  late final AuthService _authService;
  late final LocationService _locationService;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedServices = [];
  bool _isLoading = false;
  bool _isLocating = false;
  bool _isUploadingImage = false;
  double? _latitude;
  double? _longitude;

  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;

  final _services = AppCategories.all;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _locationService = context.read<LocationService>();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;
      final address = await _locationService.getAddressFromCoordinates(
        _latitude!, _longitude!,
      );
      if (mounted) {
        setState(() {
          _locationController.text = address;
          _isLocating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (image != null && mounted) {
        setState(() {
          _profileImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showServicePicker() async {
    final tempSelected = List<String>.from(_selectedServices);
    String query = '';

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = _services
              .where((s) => s.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Text('Select Services',
                            style: AppTheme.headline(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, tempSelected),
                          child: Text('Done',
                              style: AppTheme.body(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      onChanged: (v) => setSheet(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline, size: 20),
                        hintText: 'Search services...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('No service found',
                                style: AppTheme.body(color: AppColors.outline)),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final svc = filtered[i];
                              final isSelected = tempSelected.contains(svc);
                              return CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                title: Text(svc,
                                    style: AppTheme.body(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.onSurface,
                                    )),
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: (checked) => setSheet(() {
                                  if (checked == true) {
                                    tempSelected.add(svc);
                                  } else {
                                    tempSelected.remove(svc);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      setState(() => _selectedServices
        ..clear()
        ..addAll(result));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service type')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? photoUrl;
      if (_profileImage != null) {
        setState(() => _isUploadingImage = true);
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/dwydpp8ip/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = 'Triozy';

          if (kIsWeb) {
            final imageBytes = await _profileImage!.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'file',
              imageBytes,
              filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ));
          } else {
            request.files.add(await http.MultipartFile.fromPath(
              'file',
              _profileImage!.path,
            ));
          }

          final response = await request.send();
          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonMap = json.decode(responseData);
            photoUrl = jsonMap['secure_url'];
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo upload failed. Continuing without photo.'),
                  backgroundColor: AppColors.tertiary,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo upload error: $e'),
                backgroundColor: AppColors.tertiary,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }

      final exp = int.tryParse(_experienceController.text) ?? 0;

      await _authService.saveWorkerProfile(
        uid: user.uid,
        skills: _selectedServices,
        experience: exp,
        location: _locationController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        photoUrl: photoUrl,
      );

      // Activate the worker profile directly
      await _authService.activateWorkerProfile(uid: user.uid);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell(isWorker: true)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          tooltip: 'Go back',
                          onPressed: () async {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              // Revert role to customer so _RoleRouter sends them back to MainShell
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await _authService.saveUser(
                                  uid: user.uid,
                                  name: user.displayName ?? '',
                                  email: user.email ?? '',
                                  role: 'customer',
                                  photoUrl: user.photoURL,
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Triozy',
                          style: AppTheme.headline(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blue700,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          backgroundImage:
                              FirebaseAuth.instance.currentUser?.photoURL != null
                              ? NetworkImage(
                                  FirebaseAuth.instance.currentUser!.photoURL!,
                                )
                              : null,
                          child: FirebaseAuth.instance.currentUser?.photoURL == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.outline,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.error),
                          tooltip: 'Logout',
                          onPressed: () => _authService.signOut(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Form Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // Header
                      Text(
                        'Register as Service Provider',
                        style: AppTheme.headline(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Join our elite network of service professionals and start receiving requests today.',
                        style: AppTheme.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Photo Upload
                      GestureDetector(
                        onTap: _isLoading ? null : _pickImage,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _profileImage != null
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_profileImage != null)
                                ClipOval(
                                  child: kIsWeb
                                      ? Image.network(
                                          _profileImage!.path,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_profileImage!.path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                )
                              else
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo,
                                    color: AppColors.onPrimaryFixed,
                                    size: 28,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                _profileImage != null ? 'Change Profile Photo' : 'Upload Profile Photo',
                                style: AppTheme.headline(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profileImage != null ? 'Image selected' : 'Show customers who you are',
                                style: AppTheme.body(
                                  fontSize: 14,
                                  color: _profileImage != null ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      _buildField(
                        label: 'FULL NAME',
                        icon: Icons.person,
                        child: TextFormField(
                          controller: _nameController,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration('e.g. John Doe'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phone Number
                      _buildField(
                        label: 'PHONE NUMBER',
                        icon: Icons.call,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration('+1 (555) 000-0000'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Service Type
                      _buildField(
                        label: 'SERVICE TYPE',
                        icon: Icons.handyman,
                        child: FormField<List<String>>(
                          validator: (_) =>
                              _selectedServices.isEmpty ? 'Required' : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  await _showServicePicker();
                                  field.didChange(_selectedServices);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                  child: _selectedServices.isEmpty
                                      ? Text(
                                          'Select your expertise',
                                          style: AppTheme.body(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.outlineVariant,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: _selectedServices
                                              .map((s) => Chip(
                                                    label: Text(s,
                                                        style: AppTheme.body(
                                                            fontSize: 13,
                                                            color: AppColors.primary)),
                                                    backgroundColor:
                                                        AppColors.primaryFixed,
                                                    padding: EdgeInsets.zero,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    side: BorderSide.none,
                                                  ))
                                              .toList(),
                                        ),
                                ),
                              ),
                              if (field.hasError)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 12, bottom: 8),
                                  child: Text(field.errorText!,
                                      style: AppTheme.body(
                                          fontSize: 12,
                                          color: AppColors.error)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location with GPS button
                      _buildField(
                        label: 'AREA / LOCATION',
                        icon: Icons.map,
                        child: TextFormField(
                          controller: _locationController,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration(
                            'Enter city or use GPS',
                          ).copyWith(
                            suffixIcon: _isLocating
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // GPS detect button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _detectLocation,
                          icon: Icon(
                            Icons.my_location,
                            size: 18,
                            color: _latitude != null
                                ? AppColors.secondary
                                : AppColors.primary,
                          ),
                          label: Text(
                            _latitude != null
                                ? '✓ Location Detected'
                                : 'Use My Current Location',
                            style: AppTheme.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _latitude != null
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: _latitude != null
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Experience
                      _buildField(
                        label: 'EXPERIENCE (YEARS)',
                        icon: Icons.work_history,
                        child: TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration('Years of experience'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _buildField(
                        label: 'ABOUT YOUR SERVICE',
                        icon: Icons.description,
                        child: TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration(
                            'Describe your skills, specialties, and what makes you stand out...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _isLoading ? null : _submit,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _isUploadingImage
                                                ? 'Uploading photo...'
                                                : 'Register & Get Started',
                                            style: AppTheme.headline(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.rocket_launch,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Terms
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'By clicking Register, you agree to our ',
                              style: AppTheme.body(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: 'Terms of Service',
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const PolicyScreen(type: PolicyType.terms))),
                            ),
                            TextSpan(
                              text: ' and ',
                              style: AppTheme.body(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const PolicyScreen(type: PolicyType.privacy))),
                            ),
                            TextSpan(
                              text: '.',
                              style: AppTheme.body(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Trust Signals
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.green50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.verified_user_rounded,
                                      color: AppColors.secondary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Verified Badge',
                                    style: AppTheme.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.blue50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Premium Listing',
                                    style: AppTheme.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTheme.label(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.body(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.outlineVariant,
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}
