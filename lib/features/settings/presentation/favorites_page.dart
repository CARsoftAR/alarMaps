import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/favorite_location.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/services/search_service.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Mis Lugares', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return _buildFavoriteCard(context, ref, favorite);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        label: const Text('Agregar Lugar'),
        icon: const Icon(Icons.add_location_alt),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars_rounded, size: 80, color: Colors.blue.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes favoritos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega tus destinos frecuentes para\nactivar la alarma con un solo toque.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, WidgetRef ref, FavoriteLocation favorite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.place, color: Colors.blue),
        ),
        title: Text(favorite.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(favorite.address, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.radar, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text('Radio: ${favorite.alarmRadius.toInt()}m', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showAddEditDialog(context, ref, favorite: favorite);
            } else if (value == 'delete') {
              _showDeleteConfirm(context, ref, favorite);
            }
          },
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, FavoriteLocation favorite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar favorito'),
        content: Text('¿Estás seguro de que quieres eliminar "${favorite.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(favoritesProvider.notifier).deleteFavorite(favorite.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, {FavoriteLocation? favorite}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddEditFavoriteForm(favorite: favorite),
    );
  }
}

class _AddEditFavoriteForm extends ConsumerStatefulWidget {
  final FavoriteLocation? favorite;
  const _AddEditFavoriteForm({this.favorite});

  @override
  ConsumerState<_AddEditFavoriteForm> createState() => _AddEditFavoriteFormState();
}

class _AddEditFavoriteFormState extends ConsumerState<_AddEditFavoriteForm> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  double _radius = 500;
  bool _isValidating = false;
  LatLng? _validatedLocation;
  String? _validatedAddress;

  @override
  void initState() {
    super.initState();
    if (widget.favorite != null) {
      _nameController.text = widget.favorite!.name;
      _addressController.text = widget.favorite!.address;
      _radius = widget.favorite!.alarmRadius;
      _validatedLocation = LatLng(widget.favorite!.latitude, widget.favorite!.longitude);
      _validatedAddress = widget.favorite!.address;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.favorite == null ? 'Nuevo Destino' : 'Editar Destino',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre (ej: Trabajo)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Dirección o Ciudad',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.map_outlined),
              suffixIcon: IconButton(
                icon: _isValidating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.check_circle_outline, color: Colors.blue),
                onPressed: _validateAddress,
              ),
            ),
          ),
          if (_validatedAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Ubicación validada: $_validatedAddress',
                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.radar, color: Colors.blue),
              const SizedBox(width: 10),
              const Text('Radio de alarma:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_radius.toInt()}m', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _radius,
            min: 200,
            max: 2000,
            divisions: 18,
            onChanged: (val) => setState(() => _radius = val),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(widget.favorite == null ? 'GUARDAR FAVORITO' : 'ACTUALIZAR CAMBIOS'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _validateAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isValidating = true);
    
    final result = await SearchService.performHardSearch(query);
    
    if (mounted) {
      setState(() {
        _isValidating = false;
        if (result != null) {
          _validatedLocation = result.location;
          _validatedAddress = result.displayFullName;
          _addressController.text = result.displayFullName;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Dirección validada correctamente!'), backgroundColor: Colors.green)
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pudimos encontrar esa dirección. Intenta ser más específico.'), backgroundColor: Colors.red)
          );
        }
      });
    }
  }

  void _save() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un nombre para el favorito')));
      return;
    }
    if (_validatedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero valida la dirección con el check azul')));
      return;
    }

    final favorite = FavoriteLocation(
      id: widget.favorite?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      address: _validatedAddress ?? _addressController.text.trim(),
      latitude: _validatedLocation!.latitude,
      longitude: _validatedLocation!.longitude,
      alarmRadius: _radius,
    );

    if (widget.favorite == null) {
      ref.read(favoritesProvider.notifier).addFavorite(favorite);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destino guardado con éxito'), backgroundColor: Colors.green)
      );
    } else {
      ref.read(favoritesProvider.notifier).updateFavorite(favorite);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios actualizados con éxito'), backgroundColor: Colors.blue)
      );
    }

    Navigator.pop(context);
  }
}
