import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/app_colors.dart';
import 'package:flutter_application_1/screens/customers/customer_list_screen.dart';
import 'package:flutter_application_1/screens/companies/company_list_screen.dart';
import 'package:flutter_application_1/screens/invoices/invoice_list_screen.dart';
import 'package:flutter_application_1/screens/products/product_list_screen.dart';
import 'package:flutter_application_1/screens/reports/reports_screen.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'ERP CRM Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildNavItem(
            context: context,
            title: 'Customers',
            icon: Icons.people,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerListScreen()),
            ),
          ),
          _buildNavItem(
            context: context,
            title: 'Companies',
            icon: Icons.business,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompanyListScreen()),
            ),
          ),
          _buildNavItem(
            context: context,
            title: 'Invoices',
            icon: Icons.receipt,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InvoiceListScreen()),
            ),
          ),
          _buildNavItem(
            context: context,
            title: 'Products',
            icon: Icons.inventory,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductListScreen()),
            ),
          ),
          _buildNavItem(
            context: context,
            title: 'Reports',
            icon: Icons.bar_chart,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  ListTile _buildNavItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      onTap: onTap,
    );
  }
}