import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({super.key});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // Controllers
  final _invoiceNumberController = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _amountController = TextEditingController();

  // Customer and company selection
  String? _selectedCustomerId;
  String? _selectedCompanyId;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _companies = [];
  
  // Invoice items
  List<Map<String, dynamic>> _invoiceItems = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomersAndCompanies();
    // Generate invoice number
    _generateInvoiceNumber();
    
    // Add an initial empty invoice item
    _invoiceItems.add({
      'description': '',
      'quantity': 1,
      'price': 0.0,
      'amount': 0.0,
    });
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomersAndCompanies() async {
    try {
      // Load customers
      final customersResponse = await _supabase
          .from('customers')
          .select('id, name')
          .order('name', ascending: true);
      
      // Load companies
      final companiesResponse = await _supabase
          .from('companies')
          .select('id, name')
          .order('name', ascending: true);
      
      setState(() {
        _customers = List<Map<String, dynamic>>.from(customersResponse);
        _companies = List<Map<String, dynamic>>.from(companiesResponse);
        
        // Set defaults if available
        if (_customers.isNotEmpty) {
          _selectedCustomerId = _customers[0]['id'];
        }
        
        if (_companies.isNotEmpty) {
          _selectedCompanyId = _companies[0]['id'];
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
    }
  }

  void _generateInvoiceNumber() {
    // Simple invoice number generation logic
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final randomPart = (1000 + now.millisecondsSinceEpoch % 9000).toString();
    
    _invoiceNumberController.text = 'INV-$year$month-$randomPart';
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate ? _issueDate : _dueDate,
      firstDate: isIssueDate ? DateTime(2020) : _issueDate,
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
          // Update due date if it's before the issue date
          if (_dueDate.isBefore(_issueDate)) {
            _dueDate = _issueDate.add(const Duration(days: 30));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _updateInvoiceItem(int index, String field, dynamic value) {
    setState(() {
      _invoiceItems[index][field] = value;
      
      // Recalculate amount
      if (field == 'quantity' || field == 'price') {
        final quantity = double.tryParse(_invoiceItems[index]['quantity'].toString()) ?? 0;
        final price = double.tryParse(_invoiceItems[index]['price'].toString()) ?? 0;
        _invoiceItems[index]['amount'] = quantity * price;
      }
      
      // Update total amount
      _calculateTotal();
    });
  }
  
  void _addInvoiceItem() {
    setState(() {
      _invoiceItems.add({
        'description': '',
        'quantity': 1,
        'price': 0.0,
        'amount': 0.0,
      });
    });
  }
  
  void _removeInvoiceItem(int index) {
    setState(() {
      if (_invoiceItems.length > 1) {
        _invoiceItems.removeAt(index);
        _calculateTotal();
      }
    });
  }
  
  void _calculateTotal() {
    double total = 0;
    for (var item in _invoiceItems) {
      total += (item['amount'] as double);
    }
    _amountController.text = total.toStringAsFixed(2);
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomerId == null || _selectedCompanyId == null) {
      setState(() {
        _errorMessage = 'Please select both a customer and company';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, create the invoice
      final invoiceData = {
        'invoice_number': _invoiceNumberController.text,
        'customer_id': _selectedCustomerId,
        'company_id': _selectedCompanyId,
        'amount': double.parse(_amountController.text),
        'status': 'Pending',
        'issue_date': _issueDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('invoices')
          .insert(invoiceData)
          .select('id')
          .single();

      final invoiceId = response['id'];

      // Then create the invoice items related to this invoice
      for (var item in _invoiceItems) {
        if (item['description'].toString().trim().isNotEmpty) {
          await _supabase.from('invoice_items').insert({
            'invoice_id': invoiceId,
            'description': item['description'],
            'quantity': item['quantity'],
            'price': item['price'],
            'amount': item['amount'],
          });
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create invoice: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Invoice'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice Header
                    const Text(
                      'Invoice Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Invoice number
                    TextFormField(
                      controller: _invoiceNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Invoice number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Customer selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        prefixIcon: Icon(Icons.person),
                      ),
                      value: _selectedCustomerId,
                      items: _customers.map((customer) {
                        return DropdownMenuItem<String>(
                          value: customer['id'],
                          child: Text(customer['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomerId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a customer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Company selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Company',
                        prefixIcon: Icon(Icons.business),
                      ),
                      value: _selectedCompanyId,
                      items: _companies.map((company) {
                        return DropdownMenuItem<String>(
                          value: company['id'],
                          child: Text(company['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCompanyId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a company';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Selection
                    Row(
                      children: [
                        // Issue Date
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Issue Date',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_issueDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Due Date
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Due Date',
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_dueDate),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Invoice Items
                    const Text(
                      'Invoice Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Invoice Items List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _invoiceItems.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Item ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete, 
                                        color: _invoiceItems.length > 1 ? AppColors.error : Colors.grey,
                                      ),
                                      onPressed: _invoiceItems.length > 1 
                                          ? () => _removeInvoiceItem(index)
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  initialValue: _invoiceItems[index]['description'].toString(),
                                  onChanged: (value) {
                                    _updateInvoiceItem(index, 'description', value);
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Quantity
                                    Expanded(
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        ),
                                        initialValue: _invoiceItems[index]['quantity'].toString(),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          _updateInvoiceItem(index, 'quantity', double.tryParse(value) ?? 0);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Price
                                    Expanded(
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Price',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          prefixText: '\$ ',
                                        ),
                                        initialValue: _invoiceItems[index]['price'].toString(),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          _updateInvoiceItem(index, 'price', double.tryParse(value) ?? 0);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Amount (calculated)
                                    Expanded(
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Amount',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          prefixText: '\$ ',
                                        ),
                                        initialValue: _invoiceItems[index]['amount'].toString(),
                                        readOnly: true,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Add Item Button
                    OutlinedButton.icon(
                      onPressed: _addInvoiceItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Total Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount',
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveInvoice,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Create Invoice'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}