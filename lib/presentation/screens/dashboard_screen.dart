import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/auth_provider.dart';
import '../../presentation/widgets/permission_guard.dart';
import 'products_screen.dart';
import 'add_movement_screen.dart';
import 'categories_screen.dart';
import 'product_form_screen.dart';
import 'users_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync  = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentUser    = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, size: 30, color: Colors.white),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LogiStock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text(
                  currentUser?.nombre ?? 'Inventario',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // ── Botón Usuarios (solo superAdmin) ──────────────────────────────
          PermissionGuard(
            check: (p) => p.canManageUsers,
            child: IconButton(
              icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white),
              tooltip: 'Gestión de Usuarios',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              ),
            ),
          ),
          // ── Chip de rol ───────────────────────────────────────────────────
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentUser.rol.label,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          // ── Logout ────────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Deseas cerrar tu sesión?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        child: const Text('Cerrar sesión',
                            style: TextStyle(color: Colors.white))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authControllerProvider).logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── BOTÓN PRINCIPAL: REGISTRAR MOVIMIENTO ─────────────────────
            const SizedBox(height: 8),
            PermissionGuard(
              check: (p) => p.canRegisterMovements,
              child: _buildMainActionCard(
                context,
                label: 'REGISTRAR MOVIMIENTO',
                subtitle: 'Entrada o Salida de mercancía',
                icon: Icons.swap_vert_circle,
                color: const Color(0xFF0D47A1),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMovementScreen()),
                ),
              ),
              fallback: _buildBlockedCard(
                'Solo lectura',
                'No tienes permiso para registrar movimientos',
                Icons.lock_outline,
              ),
            ),
            const SizedBox(height: 24),

            // ── RESUMEN DE STOCK ──────────────────────────────────────────
            const Text('Estado del Inventario',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            productsAsync.when(
              data: (products) {
                final totalProducts = products.length;
                final lowStockCount = products.where((p) => p.isLowStock).length;
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMiniCard(context,
                          title: 'Productos',
                          value: totalProducts.toString(),
                          icon: Icons.inventory_2,
                          color: Colors.blue,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProductsScreen()))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryMiniCard(context,
                          title: 'Alertas',
                          value: lowStockCount.toString(),
                          icon: Icons.warning_rounded,
                          color: lowStockCount > 0 ? Colors.red : Colors.green,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProductsScreen(
                                      showLowStockOnly: true)))),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),

            const SizedBox(height: 32),

            // ── CATEGORÍAS ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PermissionGuard(
                  check: (p) => p.canManageCategories,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('GESTIONAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade900,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const Text('Sin categorías');
                return SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return _buildCategoryItem(context, cat.name, cat.id);
                    },
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error al cargar categorías'),
            ),

            const SizedBox(height: 32),

            // ── ACCIONES SECUNDARIAS ──────────────────────────────────────
            const Text('Otras Operaciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                // Nuevo Producto (admin+)
                PermissionGuard(
                  check: (p) => p.canManageProducts,
                  child: _buildSecondaryAction(context,
                      label: 'Nuevo Producto',
                      icon: Icons.add_box,
                      color: Colors.teal,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProductFormScreen()))),
                  fallback: _buildSecondaryAction(context,
                      label: 'Nuevo Producto',
                      icon: Icons.add_box,
                      color: Colors.grey,
                      onTap: null),
                ),
                // Ver Productos (todos)
                _buildSecondaryAction(context,
                    label: 'Ver Productos',
                    icon: Icons.format_list_bulleted,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProductsScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ─────────────────────────────────────────────────────────

  Widget _buildBlockedCard(String label, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.grey.shade500, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionCard(BuildContext context,
      {required String label,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard(BuildContext context,
      {required String title,
      required String value,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, String name, String id) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductsScreen(initialCategoryId: id))),
      child: Container(
        width: 105,
        margin: const EdgeInsets.only(right: 14, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
          border: Border.all(color: Colors.blue.shade50),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              radius: 20,
              child: Icon(Icons.category,
                  color: Colors.blue.shade800, size: 20),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(BuildContext context,
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
