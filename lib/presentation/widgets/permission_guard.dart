import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions.dart';
import '../../domain/providers/auth_provider.dart';

/// Widget guard que renderiza [child] solo si el usuario actual
/// tiene el permiso requerido según [check].
///
/// Ejemplo:
/// ```dart
/// PermissionGuard(
///   check: (p) => p.canManageUsers,
///   child: ElevatedButton(onPressed: ..., child: Text('Usuarios')),
///   fallback: SizedBox.shrink(), // opcional
/// )
/// ```
class PermissionGuard extends ConsumerWidget {
  final bool Function(RolePermissions permissions) check;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.check,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(currentPermissionsProvider);
    if (check(permissions)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
