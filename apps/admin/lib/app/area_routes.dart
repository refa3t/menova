import '../features/auth/domain/admin_access.dart';

/// Where each built section of the panel lives (P3-01).
const areaRoutes = {
  AdminArea.products: '/products',
  AdminArea.ingredients: '/ingredients',
  AdminArea.assets: '/assets',
  AdminArea.categories: '/categories',
  AdminArea.catalogCheck: '/check',
  AdminArea.settings: '/settings',
  AdminArea.reports: '/reports',
  AdminArea.audit: '/audit',
};

/// Whether [role] may open [location]: a section's pages only for the roles
/// that manage it (a typed link included), the rest for every admin.
bool mayOpen(AdminRole role, String location) {
  for (final e in areaRoutes.entries) {
    if (location == e.value || location.startsWith('${e.value}/')) {
      return canManage(role, e.key);
    }
  }
  return true;
}
