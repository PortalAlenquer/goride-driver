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
  int  _step    = 0;
  bool _loading = false;

  // ── Veículo ───────────────────────────────────────────────────
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl  = TextEditingController();

  List<dynamic>         _parents        = [];
  Map<String, dynamic>? _selectedParent;
  Map<String, dynamic>? _selectedChild;

  String? _existingVehicleId;
  File?   _vehicleDocPhoto;
  String? _existingVehicleDocUrl;

  // ── CNH ───────────────────────────────────────────────────────
  final _cnhNumberCtrl = TextEditingController();
  String    _cnhCategory = 'B';
  DateTime? _cnhExpiry;
  File?     _cnhPhoto;
  String?   _existingCnhUrl;

  // Estado de carregamento por fonte
  bool _loadingDriver     = true;
  bool _loadingCategories = true;

  final _picker = ImagePicker();

  String _storageUrl(String path) {
    final base = ApiClient().dio.options.baseUrl.replaceAll('/api', '');
    return '$base/storage/$path';
  }

  List<dynamic> get _currentChildren =>
      (_selectedParent?['children'] as List?) ?? [];

  @override
  void initState() {
    super.initState();
    // Carrega em paralelo mas trata cada um independentemente
    _loadCategories();
    _loadDriverData();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _cnhNumberCtrl.dispose();
    super.dispose();
  }

  // ── Carrega categorias independente do driver ─────────────────

  Future<void> _loadCategories() async {
    try {
      // Rota FORA do prefix /vehicles para evitar conflito com /{id}
      final res = await ApiClient().dio.get('/vehicle-categories');
      final parents = res.data['categories'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _parents           = parents;
        _loadingCategories = false;
      });
      // Re-tenta restaurar seleção se driver já carregou
      _tryRestoreSelection();
    } catch (e) {
      debugPrint('[CATEGORIES] Erro: $e');
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ── Carrega dados do motorista independente das categorias ────

  Future<void> _loadDriverData() async {
    try {
      final res    = await ApiClient().dio.get('/driver/me');
      final driver = res.data['driver'] as Map<String, dynamic>?;
      if (!mounted) return;

      // CNH
      if (driver?['cnh_number'] != null) {
        _cnhNumberCtrl.text = driver!['cnh_number'].toString();
        _cnhCategory = driver['cnh_category']?.toString() ?? 'B';
        if (driver['cnh_expiry'] != null) {
          _cnhExpiry = DateTime.tryParse(driver['cnh_expiry'].toString());
        }
      }
      if (driver?['cnh_document'] != null) {
        _existingCnhUrl = _storageUrl(driver!['cnh_document'].toString());
      }

      // Veículo
      final vehicles = driver?['vehicles'] as List?;
      if (vehicles != null && vehicles.isNotEmpty) {
        final v = vehicles.first as Map<String, dynamic>;
        _existingVehicleId = v['id']?.toString();
        _brandCtrl.text    = v['brand']?.toString() ?? '';
        _modelCtrl.text    = v['model']?.toString() ?? '';
        _plateCtrl.text    = v['plate']?.toString() ?? '';
        _colorCtrl.text    = v['color']?.toString() ?? '';
        _yearCtrl.text     = v['year']?.toString()  ?? '';
        if (v['document'] != null) {
          _existingVehicleDocUrl = _storageUrl(v['document'].toString());
        }
        // Salva o catId para restaurar depois que as categorias carregarem
        _pendingCatId = v['vehicle_category_id']?.toString();
      }

      setState(() => _loadingDriver = false);
      _tryRestoreSelection();
    } catch (e) {
      debugPrint('[DRIVER] Erro: $e');
      if (mounted) setState(() => _loadingDriver = false);
    }
  }

  // catId pendente — aguarda ambos carregarem para restaurar seleção
  String? _pendingCatId;

  void _tryRestoreSelection() {
    if (_loadingDriver || _loadingCategories) return;
    if (_pendingCatId == null || _parents.isEmpty) return;

    for (final parent in _parents) {
      final p        = parent as Map<String, dynamic>;
      final children = p['children'] as List? ?? [];
      for (final child in children) {
        final c = child as Map<String, dynamic>;
        if (c['id']?.toString() == _pendingCatId) {
          if (mounted) {
            setState(() {
              _selectedParent = p;
              _selectedChild  = c;
            });
          }
          return;
        }
      }
    }
  }

  // ── Picker de imagem ──────────────────────────────────────────

  Future<void> _pickImage(bool isCnh) async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isCnh) _cnhPhoto = File(picked.path);
        else _vehicleDocPhoto = File(picked.path);
      });
    }
  }

  // ── Salvar veículo ────────────────────────────────────────────

  Future<void> _saveVehicle() async {
    if (_brandCtrl.text.isEmpty || _plateCtrl.text.isEmpty) {
      _showSnack('Preencha todos os campos obrigatórios.');
      return;
    }
    if (_selectedChild == null) {
      _showSnack('Selecione a categoria do veículo.');
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
        'vehicle_category_id': _selectedChild!['id'],
        'is_active':           true,
      };

      if (_existingVehicleId != null) {
        await ApiClient().dio.put('/vehicles/$_existingVehicleId', data: data);
      } else {
        final res = await ApiClient().dio.post('/vehicles', data: data);
        _existingVehicleId = res.data['vehicle']['id']?.toString();
      }

      if (_vehicleDocPhoto != null && _existingVehicleId != null) {
        final formData = FormData.fromMap({
          'document': await MultipartFile.fromFile(
              _vehicleDocPhoto!.path, filename: 'vehicle_doc.jpg'),
        });
        final res = await ApiClient().dio
            .post('/vehicles/$_existingVehicleId/document', data: formData);
        final path = res.data['path']?.toString();
        if (path != null) setState(() => _existingVehicleDocUrl = _storageUrl(path));
      }

      if (mounted) setState(() => _step = 1);
    } on DioException catch (e) {
      _showSnack(
        e.response?.data['message']?.toString() ?? 'Erro ao salvar veículo.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Salvar CNH ────────────────────────────────────────────────

  Future<void> _saveCnh() async {
    if (_cnhNumberCtrl.text.isEmpty || _cnhExpiry == null) {
      _showSnack('Preencha todos os campos da CNH.');
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
        final res = await ApiClient().dio
            .post('/driver/cnh/document', data: formData);
        final path = res.data['path']?.toString();
        if (path != null) setState(() => _existingCnhUrl = _storageUrl(path));
      }

      if (mounted) {
        _showSnack('Documentação enviada! Aguarde aprovação.',
            isError: false);
        context.push('/home');
      }
    } on DioException catch (e) {
      _showSnack(
        e.response?.data['message']?.toString() ?? 'Erro ao salvar CNH.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppTheme.danger : AppTheme.secondary,
    ));
  }

  Widget _buildImagePreview({
    File? localFile, String? networkUrl, required bool isCnh,
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
          networkUrl, fit: BoxFit.cover, width: double.infinity,
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
          Text(
            isCnh
              ? 'Toque para tirar foto da CNH'
              : 'Toque para enviar foto do CRLV',
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
          color:        const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (localFile != null || networkUrl != null)
                ? AppTheme.secondary : Colors.grey.shade300),
        ),
        child: child,
      ),
    );
  }

  IconData _iconForName(String? name) {
    if (name == null) return Icons.directions_car;
    final n = name.toLowerCase();
    if (n.contains('moto'))     return Icons.two_wheeler;
    if (n.contains('van'))      return Icons.airport_shuttle;
    if (n.contains('caminh'))   return Icons.local_shipping;
    return Icons.directions_car;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Mostra loading completo só se ambos ainda estiverem carregando
    final stillLoading = _loadingDriver && _loadingCategories;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Veículo e documentos'),
        leading: _step > 0
          ? IconButton(
              icon:      const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step--))
          : IconButton(
              icon:      const Icon(Icons.arrow_back),
              onPressed: () => context.push('/home')),
      ),
      body: stillLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [

            LinearProgressIndicator(
              value:           (_step + 1) / 2,
              backgroundColor: Colors.grey.shade200,
              color:           AppTheme.secondary,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Passo ${_step + 1} de 2',
                    style: const TextStyle(
                      color: AppTheme.gray, fontSize: 12)),
                  Text(
                    ['Dados do veículo', 'Documentos CNH'][_step],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _step == 0
                  ? _buildVehicleStep()
                  : _buildCnhStep(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                    ? null
                    : (_step == 0 ? _saveVehicle : _saveCnh),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step == 0
                          ? 'Próximo — Documentos'
                          : 'Enviar documentação',
                        style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ]),
    );
  }

  // ── Step 0: Veículo ───────────────────────────────────────────

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.directions_car, size: 48, color: AppTheme.secondary),
        const SizedBox(height: 16),
        const Text('Dados do veículo',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        // ── Tipo (categoria pai) ──────────────────────────────
        const Text('Tipo de veículo',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),

        if (_loadingCategories)
          Row(children: const [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Carregando categorias...',
              style: TextStyle(color: AppTheme.gray, fontSize: 13)),
          ])
        else if (_parents.isEmpty)
          const Text('Nenhuma categoria disponível.',
            style: TextStyle(color: AppTheme.gray))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _parents.map((p) {
              final parent   = p as Map<String, dynamic>;
              final selected = _selectedParent?['id'] == parent['id'];
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedParent = parent;
                  _selectedChild  = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                      ? AppTheme.secondary.withValues(alpha: 0.1)
                      : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppTheme.secondary : Colors.transparent,
                      width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForName(parent['name']?.toString()),
                        size:  18,
                        color: selected
                            ? AppTheme.secondary : AppTheme.dark),
                      const SizedBox(width: 6),
                      Text(
                        parent['name']?.toString() ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.secondary : AppTheme.dark)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // ── Subcategoria (filho) ───────────────────────────────
        if (_selectedParent != null) ...[
          const SizedBox(height: 20),
          Text(
            'Categoria de ${_selectedParent!['name']}',
            style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.gray)),
          const SizedBox(height: 8),

          if (_currentChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                  color: AppTheme.warning, size: 16),
                SizedBox(width: 8),
                Text(
                  'Nenhuma subcategoria ativa para este tipo.',
                  style: TextStyle(
                    color: AppTheme.warning, fontSize: 13)),
              ]),
            )
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _currentChildren.map((c) {
                final child    = c as Map<String, dynamic>;
                final selected = _selectedChild?['id'] == child['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedChild = child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                        ? AppTheme.secondary.withValues(alpha: 0.1)
                        : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.secondary : Colors.transparent,
                        width: 2),
                    ),
                    child: Text(
                      child['name']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppTheme.secondary : AppTheme.dark)),
                  ),
                );
              }).toList(),
            ),
        ],

        const SizedBox(height: 20),

        // ── Dados ─────────────────────────────────────────────
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
            controller:         _plateCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Placa *'))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _colorCtrl,
            decoration: const InputDecoration(labelText: 'Cor'))),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller:   _yearCtrl,
          keyboardType: TextInputType.number,
          decoration:   const InputDecoration(labelText: 'Ano'),
        ),
        const SizedBox(height: 24),

        const Text('Documento do veículo (CRLV)',
          style: TextStyle(
            fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        _buildImagePreview(
          localFile:  _vehicleDocPhoto,
          networkUrl: _existingVehicleDocUrl,
          isCnh:      false,
        ),
      ],
    );
  }

  // ── Step 1: CNH (idêntico ao original) ───────────────────────

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
          controller:   _cnhNumberCtrl,
          keyboardType: TextInputType.number,
          decoration:   const InputDecoration(
            labelText:  'Número da CNH *',
            prefixIcon: Icon(Icons.badge_outlined)),
        ),
        const SizedBox(height: 16),

        const Text('Categoria da CNH',
          style: TextStyle(
            fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['A', 'B', 'C', 'D', 'E', 'AB'].map((cat) =>
            GestureDetector(
              onTap: () => setState(() => _cnhCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _cnhCategory == cat
                    ? AppTheme.secondary.withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _cnhCategory == cat
                        ? AppTheme.secondary : Colors.transparent,
                    width: 2),
                ),
                child: Text(cat,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _cnhCategory == cat
                        ? AppTheme.secondary : AppTheme.dark)),
              ),
            ),
          ).toList(),
        ),

        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context:     context,
              initialDate: _cnhExpiry ??
                  DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate:  DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (date != null) setState(() => _cnhExpiry = date);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _cnhExpiry != null
                    ? AppTheme.secondary : Colors.grey.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                color: AppTheme.gray, size: 20),
              const SizedBox(width: 12),
              Text(
                _cnhExpiry != null
                  ? 'Validade: '
                    '${_cnhExpiry!.day.toString().padLeft(2, '0')}/'
                    '${_cnhExpiry!.month.toString().padLeft(2, '0')}/'
                    '${_cnhExpiry!.year}'
                  : 'Selecione a validade da CNH *',
                style: TextStyle(
                  color: _cnhExpiry != null
                      ? AppTheme.dark : AppTheme.gray)),
            ]),
          ),
        ),

        const SizedBox(height: 24),
        const Text('Foto da CNH',
          style: TextStyle(
            fontWeight: FontWeight.w600, color: AppTheme.gray)),
        const SizedBox(height: 8),
        _buildImagePreview(
          localFile:  _cnhPhoto,
          networkUrl: _existingCnhUrl,
          isCnh:      true,
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        AppTheme.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Após o envio, nossa equipe irá analisar sua '
                'documentação em até 24 horas.',
                style: TextStyle(
                  color: AppTheme.warning, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }
}