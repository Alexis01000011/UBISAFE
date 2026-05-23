import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/subscription.dart';
import '../services/subscription_module.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  List<Subscription>? _subscriptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subs = await ref.read(subscriptionModuleProvider).listActive();
      if (!mounted) return;
      setState(() {
        _subscriptions = subs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las suscripciones.';
        _loading = false;
      });
    }
  }

  Future<void> _cancel(Subscription sub) async {
    // Optimistic update — remove immediately (R-F9)
    final prev = List<Subscription>.from(_subscriptions ?? []);
    setState(
      () => _subscriptions = prev.where((s) => s.id != sub.id).toList(),
    );
    try {
      await ref.read(subscriptionModuleProvider).unsubscribe(sub.id);
    } catch (_) {
      // Rollback on error
      if (!mounted) return;
      setState(() => _subscriptions = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cancelar la suscripción. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis suscripciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final subs = _subscriptions ?? [];
    if (subs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes suscripciones activas.\nAbre el perfil de un vendedor en el mapa para suscribirte.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: subs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _buildTile(subs[i]),
    );
  }

  Widget _buildTile(Subscription sub) {
    final createdLabel = _formatDate(sub.createdAt);
    final shortId = sub.vendorUid.length > 8
        ? '${sub.vendorUid.substring(0, 8)}…'
        : sub.vendorUid;

    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.storefront_outlined),
      ),
      title: Text('Vendedor $shortId'),
      subtitle: createdLabel != null ? Text('Desde $createdLabel') : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Cancelar suscripción',
        onPressed: () => _cancel(sub),
      ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return null;
    }
  }
}
