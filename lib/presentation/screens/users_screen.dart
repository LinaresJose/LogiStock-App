import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';
import '../../data/models/user_model.dart';
import '../../domain/providers/auth_provider.dart';
import 'user_form_screen.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.manage_accounts_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Gestión de Usuarios'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(usersListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserFormScreen()),
        ).then((_) => ref.invalidate(usersListProvider)),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('NUEVO USUARIO'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay usuarios registrados',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(user: user);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error al cargar usuarios:\n$e', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;
  const _UserCard({required this.user});

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.blue.shade700;
      case UserRole.operativo:
        return Colors.teal;
      case UserRole.consulta:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = _roleColor(user.rol);
    final currentUser = ref.watch(currentUserProvider);
    final isSelf = currentUser?.userId == user.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Icon(Icons.person, color: roleColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isSelf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text('Tú',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Row(
              children: [
                // Badge de rol
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    user.rol.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: user.activo
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      color: user.activo ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Creado por: ${user.creadoPorNombre} el ${user.fechaCreacion}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(
              children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')],
            )),
            PopupMenuItem(value: 'toggle', child: Row(
              children: [
                Icon(user.activo ? Icons.block : Icons.check_circle, size: 18),
                const SizedBox(width: 8),
                Text(user.activo ? 'Desactivar' : 'Activar'),
              ],
            )),
          ],
          onSelected: (action) async {
            if (action == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
              ).then((_) => ref.invalidate(usersListProvider));
            } else if (action == 'toggle') {
              if (isSelf) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('No puedes desactivar tu propia cuenta'),
                  backgroundColor: Colors.orange,
                ));
                return;
              }
              await ref.read(authControllerProvider).toggleUserActive(user);
              ref.invalidate(usersListProvider);
            }
          },
        ),
      ),
    );
  }
}
