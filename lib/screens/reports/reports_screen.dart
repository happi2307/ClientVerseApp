import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Tab controller
  late TabController _tabController;
  
  // Formatters
  final currencyFormat = NumberFormat.currency(symbol: '\$');
  final dateFormat = DateFormat('MMM dd, yyyy');
  
  // Report data
  Map<String, dynamic> _salesData = {};
  Map<String, dynamic> _customerData = {};
  Map<String, dynamic> _productData = {};
  
  // Date range
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  // Chart display settings
  bool _showLabels = true;
  bool _showValues = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load sales data
      await _loadSalesData();
      
      // Load customer data
      await _loadCustomerData();
      
      // Load product data
      await _loadProductData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading report data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadSalesData() async {
    // Fetch invoices within date range
    final response = await _supabase
        .from('invoices')
        .select()
        .gte('issue_date', _dateRange.start.toIso8601String())
        .lte('issue_date', _dateRange.end.toIso8601String());
    
    final invoices = List<Map<String, dynamic>>.from(response);
    
    // Calculate total sales
    final totalSales = invoices.fold(0.0, (sum, invoice) => sum + (invoice['amount'] ?? 0.0));
    
    // Calculate paid vs unpaid
    final paidInvoices = invoices.where((invoice) => invoice['status']?.toLowerCase() == 'paid').toList();
    final totalPaid = paidInvoices.fold(0.0, (sum, invoice) => sum + (invoice['amount'] ?? 0.0));
    final totalUnpaid = totalSales - totalPaid;
    
    // Group by month for chart data
    final monthlySales = <String, double>{};
    for (final invoice in invoices) {
      final date = DateTime.parse(invoice['issue_date']);
      final monthYear = DateFormat('MMM yyyy').format(date);
      
      monthlySales[monthYear] = (monthlySales[monthYear] ?? 0.0) + (invoice['amount'] ?? 0.0);
    }
    
    setState(() {
      _salesData = {
        'totalSales': totalSales,
        'totalPaid': totalPaid,
        'totalUnpaid': totalUnpaid,
        'invoiceCount': invoices.length,
        'paidCount': paidInvoices.length,
        'monthlySales': monthlySales,
      };
    });
  }

  Future<void> _loadCustomerData() async {
    // Fetch customers
    final customerResponse = await _supabase.from('customers').select('id, name');
    final customers = List<Map<String, dynamic>>.from(customerResponse);
    
    // Fetch invoices within date range
    final invoiceResponse = await _supabase
        .from('invoices')
        .select('''
          *,
          customers:customer_id(name)
        ''')
        .gte('issue_date', _dateRange.start.toIso8601String())
        .lte('issue_date', _dateRange.end.toIso8601String());
    
    final invoices = List<Map<String, dynamic>>.from(invoiceResponse);
    
    // Group by customer
    final customerSales = <String, double>{};
    final customerInvoiceCounts = <String, int>{};
    
    for (final invoice in invoices) {
      final customerName = invoice['customers']?['name'] ?? 'Unknown';
      
      customerSales[customerName] = (customerSales[customerName] ?? 0.0) + (invoice['amount'] ?? 0.0);
      customerInvoiceCounts[customerName] = (customerInvoiceCounts[customerName] ?? 0) + 1;
    }
    
    // Sort by sales value descending
    final sortedCustomers = customerSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Get top 5 customers
    final topCustomers = sortedCustomers.take(5).toList();
    
    setState(() {
      _customerData = {
        'totalCustomers': customers.length,
        'customerSales': customerSales,
        'customerInvoiceCounts': customerInvoiceCounts,
        'topCustomers': topCustomers,
      };
    });
  }

  Future<void> _loadProductData() async {
    // Fetch products
    final productResponse = await _supabase.from('products').select();
    final products = List<Map<String, dynamic>>.from(productResponse);
    
    // Calculate total inventory value
    final totalInventoryValue = products.fold(0.0, (sum, product) {
      return sum + ((product['price'] ?? 0.0) * (product['stock_quantity'] ?? 0));
    });
    
    // Calculate products by category
    final categories = <String, int>{};
    final categoryValue = <String, double>{};
    
    for (final product in products) {
      final category = product['category'] ?? 'Uncategorized';
      
      categories[category] = (categories[category] ?? 0) + 1;
      categoryValue[category] = (categoryValue[category] ?? 0.0) + 
          ((product['price'] ?? 0.0) * (product['stock_quantity'] ?? 0));
    }
    
    // Find low stock products (less than 5 in stock)
    final lowStockProducts = products.where((product) {
      return (product['stock_quantity'] ?? 0) < 5 && (product['stock_quantity'] ?? 0) > 0;
    }).toList();
    
    // Find out of stock products
    final outOfStockProducts = products.where((product) {
      return (product['stock_quantity'] ?? 0) <= 0;
    }).toList();
    
    setState(() {
      _productData = {
        'totalProducts': products.length,
        'totalInventoryValue': totalInventoryValue,
        'categories': categories,
        'categoryValue': categoryValue,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
      };
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Customers'),
            Tab(text: 'Products'),
          ],
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
        actions: [
          // Date range selector
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReportData,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSalesReportTab(),
                    _buildCustomerReportTab(),
                    _buildProductReportTab(),
                  ],
                ),
    );
  }

  Widget _buildSalesReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildReportCardGrid([
            _buildSummaryCard(
              title: 'Total Sales',
              value: currencyFormat.format(_salesData['totalSales'] ?? 0),
              icon: Icons.trending_up,
              color: AppColors.primary,
            ),
            _buildSummaryCard(
              title: 'Total Invoices',
              value: (_salesData['invoiceCount'] ?? 0).toString(),
              icon: Icons.receipt,
              color: Colors.orange,
            ),
            _buildSummaryCard(
              title: 'Paid',
              value: currencyFormat.format(_salesData['totalPaid'] ?? 0),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Outstanding',
              value: currencyFormat.format(_salesData['totalUnpaid'] ?? 0),
              icon: Icons.warning,
              color: Colors.red,
            ),
          ]),
          
          const SizedBox(height: 24),
          
          // Monthly sales chart
          _buildSection(
            title: 'Monthly Sales',
            child: _buildChartContainer(
              height: 240,
              child: _buildMonthlySalesChart(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Payment status chart
          _buildSection(
            title: 'Payment Status',
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildChartContainer(
                    height: 180,
                    child: _buildPaymentStatusChart(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Paid', Colors.green),
                      const SizedBox(height: 8),
                      _buildLegendItem('Outstanding', Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Paid: ${(_salesData['paidCount'] ?? 0)} invoices',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Outstanding: ${(_salesData['invoiceCount'] ?? 0) - (_salesData['paidCount'] ?? 0)} invoices',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Chart settings
          _buildChartSettings(),
        ],
      ),
    );
  }

  Widget _buildCustomerReportTab() {
    final topCustomers = _customerData['topCustomers'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(
            title: 'Total Customers',
            value: (_customerData['totalCustomers'] ?? 0).toString(),
            icon: Icons.people,
            color: AppColors.secondary,
            fullWidth: true,
          ),
          
          const SizedBox(height: 24),
          
          // Top customers chart
          _buildSection(
            title: 'Top 5 Customers by Sales',
            child: _buildChartContainer(
              height: 240,
              child: topCustomers.isNotEmpty
                  ? _buildTopCustomersChart(topCustomers)
                  : const Center(
                      child: Text('No customer data available for selected period'),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Top customers table
          _buildSection(
            title: 'Customer Details',
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Table header
                    Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Customer Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total Sales',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Invoices',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Table data
                    if (topCustomers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            'No customer data available for selected period',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    else
                      ...topCustomers.map((entry) {
                        final customerName = entry.key;
                        final salesAmount = entry.value;
                        final invoiceCount = _customerData['customerInvoiceCounts']?[customerName] ?? 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(customerName),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormat.format(salesAmount),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  invoiceCount.toString(),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Chart settings
          _buildChartSettings(),
        ],
      ),
    );
  }

  Widget _buildProductReportTab() {
    final categories = _productData['categories'] as Map<String, dynamic>? ?? {};
    final lowStockProducts = _productData['lowStockProducts'] as List? ?? [];
    final outOfStockProducts = _productData['outOfStockProducts'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildReportCardGrid([
            _buildSummaryCard(
              title: 'Total Products',
              value: (_productData['totalProducts'] ?? 0).toString(),
              icon: Icons.inventory_2,
              color: AppColors.primary,
            ),
            _buildSummaryCard(
              title: 'Inventory Value',
              value: currencyFormat.format(_productData['totalInventoryValue'] ?? 0),
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'Low Stock',
              value: (lowStockProducts.length).toString(),
              icon: Icons.warning_amber,
              color: Colors.orange,
            ),
            _buildSummaryCard(
              title: 'Out of Stock',
              value: (outOfStockProducts.length).toString(),
              icon: Icons.error_outline,
              color: Colors.red,
            ),
          ]),
          
          const SizedBox(height: 24),
          
          // Products by category chart
          _buildSection(
            title: 'Products by Category',
            child: _buildChartContainer(
              height: 240,
              child: categories.isNotEmpty
                  ? _buildCategoriesChart()
                  : const Center(
                      child: Text('No category data available'),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Low stock products
          _buildSection(
            title: 'Low Stock Products',
            child: _buildProductTable(lowStockProducts),
          ),
          
          const SizedBox(height: 24),
          
          // Out of stock products
          _buildSection(
            title: 'Out of Stock Products',
            child: _buildProductTable(outOfStockProducts),
          ),
          
          const SizedBox(height: 24),
          
          // Chart settings
          _buildChartSettings(),
        ],
      ),
    );
  }

  Widget _buildReportCardGrid(List<Widget> cards) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: cards,
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildChartContainer({
    required double height,
    required Widget child,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMonthlySalesChart() {
    final monthlySales = _salesData['monthlySales'] as Map<String, dynamic>? ?? {};
    
    if (monthlySales.isEmpty) {
      return const Center(
        child: Text('No sales data available for selected period'),
      );
    }
    
    // Extract and sort months
    final months = monthlySales.keys.toList();
    final values = months.map((m) => monthlySales[m] ?? 0.0).toList();
    
    // Create bar chart data
    final barGroups = List.generate(months.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i],
            color: AppColors.primary,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ],
      );
    });
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${months[group.x]}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: currencyFormat.format(values[group.x]),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showLabels,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= months.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    months[value.toInt()],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showValues,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    currencyFormat.format(value),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: values.reduce((a, b) => a > b ? a : b) / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildPaymentStatusChart() {
    final totalPaid = _salesData['totalPaid'] ?? 0.0;
    final totalUnpaid = _salesData['totalUnpaid'] ?? 0.0;
    final total = totalPaid + totalUnpaid;
    
    if (total <= 0) {
      return const Center(
        child: Text('No payment data available'),
      );
    }
    
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: totalPaid,
            title: _showLabels ? '${((totalPaid / total) * 100).toStringAsFixed(1)}%' : '',
            color: Colors.green,
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: totalUnpaid,
            title: _showLabels ? '${((totalUnpaid / total) * 100).toStringAsFixed(1)}%' : '',
            color: Colors.red,
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomersChart(List<dynamic> topCustomers) {
    if (topCustomers.isEmpty) {
      return const Center(
        child: Text('No customer data available'),
      );
    }
    
    // Extract customer names and sales values
    final customerNames = topCustomers.map((e) => e.key as String).toList();
    final salesValues = topCustomers.map((e) => e.value as double).toList();
    
    // Create bar chart data
    final barGroups = List.generate(customerNames.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: salesValues[i],
            color: AppColors.secondary,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ],
      );
    });
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${customerNames[group.x]}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: currencyFormat.format(salesValues[group.x]),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showLabels,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= customerNames.length) {
                  return const SizedBox();
                }
                final name = customerNames[value.toInt()];
                // Truncate long names
                final displayName = name.length > 10 ? '${name.substring(0, 8)}...' : name;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showValues,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    currencyFormat.format(value),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: salesValues.reduce((a, b) => a > b ? a : b) / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildCategoriesChart() {
    final categories = _productData['categories'] as Map<String, dynamic>? ?? {};
    final categoryValues = _productData['categoryValue'] as Map<String, dynamic>? ?? {};
    
    if (categories.isEmpty) {
      return const Center(
        child: Text('No category data available'),
      );
    }
    
    // Create pie chart data
    final sections = <PieChartSectionData>[];
    final colors = [
      AppColors.primary,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
    ];
    
    int i = 0;
    for (var entry in categories.entries) {
      final color = colors[i % colors.length];
      i++;
      
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: _showLabels ? entry.key : '',
          color: color,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(categories.length, (index) {
                  final key = categories.keys.elementAt(index);
                  final value = categories[key];
                  final color = colors[index % colors.length];
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$value items',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(title),
      ],
    );
  }

  Widget _buildChartSettings() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chart Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Labels'),
              value: _showLabels,
              onChanged: (value) {
                setState(() {
                  _showLabels = value;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Show Values'),
              value: _showValues,
              onChanged: (value) {
                setState(() {
                  _showValues = value;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTable(List<dynamic> products) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Table header
            Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Product Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Stock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Table data
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No products in this category',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ...products.take(5).map((product) {
                final stockColor = _getStockColor(product['stock_quantity'] ?? 0);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          product['name'] ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          currencyFormat.format(product['price'] ?? 0),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          (product['stock_quantity'] ?? 0).toString(),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              
            // Show more button if there are more than 5 products
            if (products.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton(
                  onPressed: () {
                    // Navigate to full product list with this filter applied
                  },
                  child: Text(
                    'View all ${products.length} products',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}