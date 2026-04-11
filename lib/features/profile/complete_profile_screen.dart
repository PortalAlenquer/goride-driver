import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  int _step = 0;
  bool _loading = false;

  // Veículo
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl  = TextEditingController();
  String? _selectedCategory;
  String _selectedType    = 'car';
  String _selectedService = 'passenger';
  List<dynamic> _categories = [];
  String? _existingVehicleId;
  File? _vehicleDocPhoto;
  String? _existingVehicleDocUrl;

  // CNH
  final _cnhNumberCtrl = TextEditingController();
  String    _cnhCategory = 'B';
  DateTime? _cnhExpiry;
  File?     _cnhPhoto;
  String?   _existingCnhUrl;

  final _picker = ImagePicker();

  String _storageUrl(String path) {
    final base = ApiClient().dio.options.baseUrl
        .replaceAll('/api', '');
    return '$base/storage/$path';
  }

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    setState(() => _loading = true);
    try {
      final driverRes = await ApiClient().dio.get('/driver/me');
      final driver    = driverRes.data['driver'];
      final franchiseId = driver?['franchise_id'];

      if (franchiseId != null) {
        final catsRes = await ApiClient().dio.get('/cities/$franchiseId/categories');
        _categories = catsRes.data['categories'];
      }

      if (driver?['cnh_number'] != null) {
        _cnhNumberCtrl.text = driver['cnh_number'];
        _cnhCategory = driver['cnh_category'] ?? 'B';
        if (driver['cnh_expiry'] != null) {
          _cnhExpiry = DateTime.tryParse(driver['cnh_expiry']);
        }
      }

      if (driver?['cnh_document'] != null) {
        _existingCnhUrl = _storageUrl(driver['cnh_document']);
      }

      final vehicles = driver?['vehicles'] as List?;
      if (vehicles != null && vehicles.isNotEmpty) {
        final v = vehicles.first;
        _existingVehicleId  = v['id'];
        _brandCtrl.text     = v['brand'] ?? '';
        _modelCtrl.text     = v['model'] ?? '';
        _plateCtrl.text     = v['plate'] ?? '';
        _colorCtrl.text     = v['color'] ?? '';
        _yearCtrl.text      = v['year']?.toString() ?? '';
        _selectedCategory   = v['vehicle_category_id'];
        _selectedType       = v['type'] ?? 'car';
        _selectedService    = v['service_type'] ?? 'passenger';
        if (v['document'] != null) {
          _existingVehicleDocUrl = _storageUrl(v['document']);
        }
      }

      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(bool isCnh) async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isCnh) {
          _cnhPhoto = File(picked.path);
        } else {
          _vehicleDocPhoto = File(picked.path);
        }
      });
    }
  }

  Future<void> _saveVehicle() async {
    if (_brandCtrl.text.isEmpty || _plateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os campos obrigatórios.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final data = {
        'brand':               _brandCtrl.text.trim(),
        'model':               _modelCtrl.text.trim(),
        'plate':               _plateCtrl.text.trim().toUpperCase(),
        'color':               _colorCtrl.text.trim(),
        'year':                int.tryParse(_yearCtrl.text.trim()) ?? 2020,
        'vehicle_category_id': _selectedCategory,
        'type':                _selectedType,
        'service_type':        _selectedService,
        'is_active':           true,
      };

      if (_existingVehicleId != null) {
        await ApiClient().dio.put('/vehicles/$_existingVehicleId', data: data);
      } else {
        final res = await ApiClient().dio.post('/vehicles', data: data);
        _existingVehicleId = res.data['vehicle']['id'];
      }

      if (_vehicleDocPhoto != null) {
        final formData = FormData.fromMap({
          'document': await MultipartFile.fromFile(
              _vehicleDocPhoto!.path, filename: 'vehicle_doc.jpg'),
        });
        final res = await ApiClient().dio.post(
            '/vehicles/$_existingVehicleId/document', data: formData);
        final path = res.data['path'];
        if (path != null) setState(() => _existingVehicleDocUrl = _storageUrl(path));
      }

      setState(() => _step = 1);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data['message'] ?? 'Erro ao salvar veículo.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCnh() async {
    if (_cnhNumberCtrl.text.isEmpty || _cnhExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os campos da CNH.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient().dio.put('/driver/cnh', data: {
        'cnh_number':   _cnhNumberCtrl.text.trim(),
        'cnh_category': _cnhCategory,
        'cnh_expiry':   _cnhExpiry!.toIso8601String().split('T')[0],
      });

      if (_cnhPhoto != null) {
        final formData = FormData.fromMap({
          'cnh_document': await MultipartFile.fromFile(
              _cnhPhoto!.path, filename: 'cnh.jpg'),
        });
        final res = await ApiClient().dio.post('/driver/cnh/document', data: formData);
        final path = res.data['path'];
        if (path != null) setState(() => _existingCnhUrl = _storageUrl(path));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Documentação enviada! Aguarde aprovação.'),
          backgroundColor: AppTheme.secondary,
        ));
        context.go('/home');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data['message'] ?? 'Erro ao salvar CNH.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildImagePreview({
    File? localFile,
    String? networkUrl,
    required bool isCnh,
  }) {
    Widget child;

    if (localFile != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(localFile, fit: BoxFit.cover, width: double.infinity),
      );
    } else if (networkUrl != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          networkUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: AppTheme.gray, size: 40)),
        ),
      );
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isCnh ? Icons.camera_alt : Icons.upload_file,
              size: isCnh ? 40 : 32, color: AppTheme.gray),
          const SizedBox(height: 8),
          Text(isCnh ? 'Toque para tirar foto da CNH' : 'Toque para enviar foto do CRLV',
              style: const TextStyle(color: AppTheme.gray)),
          Text(isCnh ? '(recomendado)' : '(opcional)',
              style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _pickImage(isCnh),
      child: Container(
        height: isCnh ? 160 : 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (localFile != null || networkUrl != null)
                ? AppTheme.secondary
                : Colors.grey.shade300),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Veículo e documentos'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--))
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home')),
      ),
      body: _loading && _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_step + 1) / 2,
                  backgroundColor: Colors.grey.shade200,
                  color: AppTheme.secondary,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Passo ${_step + 1} de 2',
                          style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
                      Text(
                        ['Dados do veículo', 'Documentos CNH'][_step],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _step == 0 ? _buildVehicleStep() : _buildCnhStep(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: _loading ? null : (_step == 0 ? _saveVehicle : _saveCnh),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_step == 0 ? 'Próximo — Documentos' : 'Enviar documentação'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.directions_car, size: 48, color: AppTheme.secondary),
        const SizedBox(height: 16),
        const Text('Dados do veículo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        const Text('Categoria',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        _categories.isEmpty
            ? const Text('Carregando categorias...', style: TextStyle(color: AppTheme.gray))
            : Wrap(
                spacing: 8, runSpacing: 8,
                children: _categories.map((cat) => GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedCategory == cat['id']
                          ? AppTheme.secondary.withValues(alpha: 0.1)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedCategory == cat['id']
                            ? AppTheme.secondary : Colors.transparent,
                        width: 2),
                    ),
                    child: Text(cat['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedCategory == cat['id']
                              ? AppTheme.secondary : AppTheme.dark)),
                  ),
                )).toList(),
              ),

        const SizedBox(height: 20),
        const Text('Tipo de veículo',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            {'value': 'car', 'label': 'Carro'},
            {'value': 'motorcycle', 'label': 'Moto'},
            {'value': 'van', 'label': 'Van'},
          ].map((t) => GestureDetector(
            onTap: () => setState(() => _selectedType = t['value']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _selectedType == t['value']
                    ? AppTheme.secondary.withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedType == t['value']
                      ? AppTheme.secondary : Colors.transparent,
                  width: 2),
              ),
              child: Text(t['label']!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _selectedType == t['value']
                        ? AppTheme.secondary : AppTheme.dark)),
            ),
          )).toList(),
        ),

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Marca *'))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Modelo *'))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(
              controller: _plateCtrl,
              decoration: const InputDecoration(labelText: 'Placa *'))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
              controller: _colorCtrl,
              decoration: const InputDecoration(labelText: 'Cor'))),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: _yearCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Ano'),
        ),

        const SizedBox(height: 24),
        const Text('Documento do veículo (CRLV)',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        _buildImagePreview(
          localFile: _vehicleDocPhoto,
          networkUrl: _existingVehicleDocUrl,
          isCnh: false,
        ),
      ],
    );
  }

  Widget _buildCnhStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.badge_outlined, size: 48, color: AppTheme.secondary),
        const SizedBox(height: 16),
        const Text('Documentos CNH',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Suas informações serão analisadas antes de você poder trabalhar.',
          style: TextStyle(color: AppTheme.gray)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _cnhNumberCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número da CNH *',
            prefixIcon: Icon(Icons.badge_outlined)),
        ),
        const SizedBox(height: 16),

        const Text('Categoria da CNH',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['A', 'B', 'C', 'D', 'E', 'AB'].map((cat) => GestureDetector(
            onTap: () => setState(() => _cnhCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _cnhCategory == cat
                    ? AppTheme.secondary.withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _cnhCategory == cat ? AppTheme.secondary : Colors.transparent,
                  width: 2),
              ),
              child: Text(cat,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _cnhCategory == cat ? AppTheme.secondary : AppTheme.dark)),
            ),
          )).toList(),
        ),

        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _cnhExpiry ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (date != null) setState(() => _cnhExpiry = date);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _cnhExpiry != null ? AppTheme.secondary : Colors.grey.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: AppTheme.gray, size: 20),
              const SizedBox(width: 12),
              Text(
                _cnhExpiry != null
                    ? 'Validade: ${_cnhExpiry!.day.toString().padLeft(2, '0')}/${_cnhExpiry!.month.toString().padLeft(2, '0')}/${_cnhExpiry!.year}'
                    : 'Selecione a validade da CNH *',
                style: TextStyle(
                  color: _cnhExpiry != null ? AppTheme.dark : AppTheme.gray)),
            ]),
          ),
        ),

        const SizedBox(height: 24),
        const Text('Foto da CNH',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        _buildImagePreview(
          localFile: _cnhPhoto,
          networkUrl: _existingCnhUrl,
          isCnh: true,
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Após o envio, nossa equipe irá analisar sua documentação em até 24 horas.',
                style: TextStyle(color: AppTheme.warning, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }
}