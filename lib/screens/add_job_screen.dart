import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/job_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AddJobScreen extends StatefulWidget {
  final JobModel? jobToEdit;
  const AddJobScreen({super.key, this.jobToEdit});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  late final DatabaseService _db;
  late final AuthService _auth;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;

  String? _selectedCategory;
  bool _isLoading = false;
  bool _isLocating = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _jobImage;

  final List<String> _categories = [
    'Electrician',
    'Plumber',
    'AC Repair',
    'Painter',
    'Carpenter',
    'Tile Worker',
    'Cleaning',
    'Maid',
    'Security',
    'Gardening',
    'Co-rider',
    'Bike Taxi',
    'Car Taxi',
    'Tempo',
    'Driver',
    'Babysitter',
    'Tailor',
    'Home Salon',
  ];

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _auth = context.read<AuthService>();
    _descriptionController = TextEditingController(text: widget.jobToEdit?.description ?? '');
    _locationController = TextEditingController(text: widget.jobToEdit?.location ?? '');
    _phoneController = TextEditingController(text: widget.jobToEdit?.phone ?? '');
    _selectedCategory = widget.jobToEdit?.category;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
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
        setState(() => _jobImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_jobImage == null) return null;
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/dwydpp8ip/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'Triozy';

      if (kIsWeb) {
        final bytes = await _jobImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file', bytes,
          filename: 'job_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', _jobImage!.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = json.decode(await response.stream.bytesToString());
        return data['secure_url'] as String?;
      }
    } catch (_) {}
    return null;
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

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload photo if selected
      String? photoUrl = widget.jobToEdit?.photoUrl;
      if (_jobImage != null) {
        photoUrl = await _uploadImage();
      }

      final job = JobModel(
        id: widget.jobToEdit?.id ?? const Uuid().v4(),
        userId: user.uid,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        phone: _phoneController.text.trim(),
        time: '',
        budgetRange: '',
        status: widget.jobToEdit?.status ?? 'Finding',
        photoUrl: photoUrl,
        createdAt: widget.jobToEdit?.createdAt ?? DateTime.now(),
      );

      if (widget.jobToEdit != null) {
        await _db.updateJob(job);
      } else {
        await _db.postJob(job);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.jobToEdit != null ? 'Job updated successfully!' : 'Job posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
        title: Text(
          widget.jobToEdit != null ? 'Edit Job' : 'Post a Job',
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
                    color: _jobImage != null ? Colors.white : AppColors.blue50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _jobImage != null
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: _jobImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _jobImage!.path,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_jobImage!.path),
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
                            Text('Add a Photo', style: AppTheme.headline(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              'Help professionals understand the issue',
                              style: AppTheme.body(fontSize: 13, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Category
              Text('SERVICE CATEGORY', style: AppTheme.label(color: AppColors.onSurfaceVariant, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.handyman, color: AppColors.primary, size: 20),
                  hintText: 'Select a service category',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                icon: const Icon(Icons.expand_more, color: AppColors.outline),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 32),

              // Description
              // Phone
              Text('PHONE NUMBER', style: AppTheme.label(color: AppColors.onSurfaceVariant, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                  hintText: 'Your contact number',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              Text('PROBLEM DESCRIPTION', style: AppTheme.label(color: AppColors.onSurfaceVariant, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Briefly describe what needs to be fixed or installed...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(20),
                ),
                validator: (v) => v!.isEmpty ? 'Please describe the issue' : null,
              ),
              const SizedBox(height: 32),

              // Location
              Text('LOCATION', style: AppTheme.label(color: AppColors.onSurfaceVariant, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  hintText: 'Enter your address',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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
                  onPressed: _isLoading ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.jobToEdit != null ? 'Update Job' : 'Post Job',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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
                      style: AppTheme.body(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    TextSpan(
                      text: 'Terms of Service',
                      style: AppTheme.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' and ',
                      style: AppTheme.body(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: AppTheme.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: '.',
                      style: AppTheme.body(fontSize: 12, color: AppColors.onSurfaceVariant),
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
