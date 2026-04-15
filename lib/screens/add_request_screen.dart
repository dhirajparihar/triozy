import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'policy_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/request_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AddRequestScreen extends StatefulWidget {
  final RequestModel? requestToEdit;
  const AddRequestScreen({super.key, this.requestToEdit});

  @override
  State<AddRequestScreen> createState() => _AddRequestScreenState();
}

class _AddRequestScreenState extends State<AddRequestScreen> {
  late final DatabaseService _db;
  late final AuthService _auth;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  late final TextEditingController _categoryController;

  bool _isLoading = false;
  bool _isLocating = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _requestImage;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _auth = context.read<AuthService>();
    _descriptionController = TextEditingController(
      text: widget.requestToEdit?.description ?? '',
    );
    _locationController = TextEditingController(
      text: widget.requestToEdit?.location ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.requestToEdit?.phone ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.requestToEdit?.category ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (image != null && mounted) {
        setState(() => _requestImage = image);
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

  Future<String?> _uploadImage() async {
    if (_requestImage == null) return null;
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/dwydpp8ip/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'Triozy';

      if (kIsWeb) {
        final bytes = await _requestImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'job_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', _requestImage!.path),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'] as String?;
      }
      throw Exception('Upload failed (${response.statusCode})');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo upload failed — request will be posted without image.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final locService = context.read<LocationService>();
      final locProvider = context.read<LocationProvider>();

      // Use shared location if already available
      if (locProvider.isAvailable) {
        _locationController.text = locProvider.address;
        setState(() => _isLocating = false);
        return;
      }

      // Otherwise fetch fresh
      final position = await locService.getCurrentPosition();
      final address = await locService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
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
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload photo if selected
      String? photoUrl = widget.requestToEdit?.photoUrl;
      if (_requestImage != null) {
        photoUrl = await _uploadImage();
      }

      final userData = await _auth.getUserData(user.uid);
      final resolvedPosterName =
          (widget.requestToEdit?.posterName.isNotEmpty == true
              ? widget.requestToEdit!.posterName
              : (userData?['name'] as String?)?.trim()) ??
          user.displayName?.trim() ??
          (user.email?.split('@').first ?? '').trim();
      final posterName = resolvedPosterName.isEmpty
          ? 'User'
          : resolvedPosterName;

      final job = RequestModel(
        id: widget.requestToEdit?.id ?? const Uuid().v4(),
        userId: user.uid,
        posterName: posterName,
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        phone: _phoneController.text.trim(),
        time: '',
        budgetRange: '',
        status: widget.requestToEdit?.status ?? 'Open',
        photoUrl: photoUrl,
        createdAt: widget.requestToEdit?.createdAt ?? DateTime.now(),
      );

      if (widget.requestToEdit != null) {
        await _db.updateRequest(job);
      } else {
        await _db.postRequest(job);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.requestToEdit != null
                  ? 'Request updated successfully!'
                  : 'Request posted successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Post a Request',
            style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.onSurface),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.tertiary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sign in to post requests',
                  style: AppTheme.headline(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Guest mode can browse the app, but posting and managing requests requires sign-in.',
                  style: AppTheme.body(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      context.read<SessionService>().exitGuestMode();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Go to Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.requestToEdit != null ? 'Edit Request' : 'Post a Request',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Upload
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _requestImage != null
                        ? Colors.white
                        : AppColors.blue50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _requestImage != null
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: _requestImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _requestImage!.path,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_requestImage!.path),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo,
                                color: AppColors.onPrimaryFixed,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add a Photo',
                              style: AppTheme.headline(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Help professionals understand the issue',
                              style: AppTheme.body(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Service needed (free-form)
              Text(
                'WHAT DO YOU NEED?',
                style: AppTheme.label(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  hintText:
                      'e.g. Yoga trainer, Drone photographer, Language tutor...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe what you need'
                    : null,
              ),
              const SizedBox(height: 32),

              // Description
              // Phone
              Text(
                'PHONE NUMBER',
                style: AppTheme.label(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.phone_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  hintText: 'Your contact number',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              Text(
                'PROBLEM DESCRIPTION',
                style: AppTheme.label(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Briefly describe what needs to be fixed or installed...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Please describe the issue' : null,
              ),
              const SizedBox(height: 32),

              // Location
              Text(
                'LOCATION',
                style: AppTheme.label(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  hintText: 'Enter your address',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
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
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLocating ? null : _detectLocation,
                  icon: Icon(
                    Icons.my_location,
                    size: 18,
                    color: _locationController.text.isNotEmpty
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
                  label: Text(
                    'Use My Current Location',
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _locationController.text.isNotEmpty
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _locationController.text.isNotEmpty
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.requestToEdit != null
                                  ? 'Update Request'
                                  : 'Post Request',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.rocket_launch),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Terms
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'By posting, you agree to our ',
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
                        ..onTap = () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PolicyScreen(type: PolicyType.terms),
                          ),
                        ),
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
                        ..onTap = () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PolicyScreen(type: PolicyType.privacy),
                          ),
                        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
