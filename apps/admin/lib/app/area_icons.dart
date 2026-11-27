import 'package:flutter/material.dart';

import '../features/auth/domain/admin_access.dart';

/// The icon of each section, shared by the navigation and the home cards.
IconData areaIcon(AdminArea a) => switch (a) {
  AdminArea.products => Icons.local_pizza_outlined,
  AdminArea.ingredients => Icons.eco_outlined,
  AdminArea.drafts => Icons.edit_note,
  AdminArea.assets => Icons.photo_library_outlined,
  AdminArea.categories => Icons.view_list_outlined,
  AdminArea.offers => Icons.local_offer_outlined,
  AdminArea.catalogCheck => Icons.fact_check_outlined,
  AdminArea.settings => Icons.storefront_outlined,
  AdminArea.reports => Icons.insights_outlined,
  AdminArea.audit => Icons.history,
};
