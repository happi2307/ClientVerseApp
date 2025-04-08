import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/app_colors.dart';
import 'package:flutter_application_1/screens/invoices/add_invoice_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Invoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String companyId;
  final String companyName;
  final double amount;
  final String status;
  final DateTime issueDate;
  final DateTime dueDate;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.companyId,
    required this.companyName,
    required this.amount,
    required this.status,
    required this.issueDate,
    required this.dueDate,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: json['company_name'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      issueDate: json['issue_date'] != null
          ? DateTime.parse(json['issue_date'])
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : DateTime.now().add(const Duration(days: 30)),
    );
  }
}

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final _supabase = Supabase.instance.client;
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  
  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'Paid', 'Pending', 'Overdue'];
  
  String _sortBy = 'Latest';
  final List<String> _sortOptions = ['Latest', 'Oldest', 'Amount: High to Low', 'Amount: Low to High'];
  
  final dateFormat = DateFormat('MMM dd, yyyy');
  final currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
    _searchController.addListener(_filterInvoices);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Here we'd typically join the invoices table with customers and companies
      // For simplicity, we'll assume the invoice data already includes customer and company names
      final response = await _supabase
          .from('invoices')
          .select('''
            *,
            customers:customer_id(name),
            companies:company_id(name)
          ''')
          .order('issue_date', ascending: false);

      final List<Invoice> invoices = (response as List).map((invoice) {
        // Extract nested data from the join
        final Map<String, dynamic> data = Map<String, dynamic>.from(invoice);
        data['customer_name'] = invoice['customers']?['name'] ?? 'Unknown Customer';
        data['company_name'] = invoice['companies']?['name'] ?? 'Unknown Company';
        return Invoice.fromJson(data);
      }).toList();

      setState(() {
        _invoices = invoices;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load invoices: ${e.toString()}';
      });
    }
  }

  void _filterInvoices() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    // First filter by search query
    var filtered = _invoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.customerName.toLowerCase().contains(query) ||
          invoice.companyName.toLowerCase().contains(query);
    }).toList();
    
    // Then filter by status
    if (_statusFilter != 'All') {
      filtered = filtered.where((invoice) => 
        invoice.status.toLowerCase() == _statusFilter.toLowerCase()
      ).toList();
    }
    
    // Finally sort
    switch (_sortBy) {
      case 'Latest':
        filtered.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a.issueDate.compareTo(b.issueDate));
        break;
      case 'Amount: High to Low':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount: Low to High':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    
    setState(() {
      _filteredInvoices = filtered;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search invoices...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // Filter options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Status filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    value: _statusFilter,
                    items: _statusOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _statusFilter = newValue;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Sort options
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    value: _sortBy,
                    items: _sortOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortBy = newValue;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Error message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
          // Invoice list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const Center(
                        child: Text(
                          'No invoices found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
                      ),
          ),
          
          // Summary footer
          if (!_isLoading && _filteredInvoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Invoices: ${_filteredInvoices.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Amount: ${currencyFormat.format(_filteredInvoices.fold(0.0, (sum, invoice) => sum + invoice.amount))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddInvoiceScreen()),
          );
          
          if (result == true) {
            _fetchInvoices();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final isOverdue = invoice.status.toLowerCase() != 'paid' && 
                      invoice.dueDate.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to invoice detail screen
          // This will be implemented later
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice header with number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoice #${invoice.invoiceNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isOverdue ? 'overdue' : invoice.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(isOverdue ? 'overdue' : invoice.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isOverdue ? 'Overdue' : invoice.status,
                      style: TextStyle(
                        color: _getStatusColor(isOverdue ? 'overdue' : invoice.status),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Customer and company info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          invoice.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          invoice.companyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Amount and dates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currencyFormat.format(invoice.amount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Issued: ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            dateFormat.format(invoice.issueDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Due: ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            dateFormat.format(invoice.dueDate),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: isOverdue ? AppColors.error : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              // Action buttons
              if (invoice.status.toLowerCase() != 'paid')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // Send reminder functionality
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Send Reminder'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Mark as paid functionality
                          _markAsPaid(invoice);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark as Paid'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _markAsPaid(Invoice invoice) async {
    try {
      await _supabase
          .from('invoices')
          .update({'status': 'Paid'})
          .eq('id', invoice.id);
      
      _fetchInvoices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating invoice: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}