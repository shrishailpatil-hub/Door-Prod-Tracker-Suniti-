import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/primary_action_button.dart';
import '../../widgets/glass/glass_card.dart';

class ManagerCreateJobScreen extends StatefulWidget {
  const ManagerCreateJobScreen({super.key});

  @override
  State<ManagerCreateJobScreen> createState() => _ManagerCreateJobScreenState();
}

class _ManagerCreateJobScreenState extends State<ManagerCreateJobScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().clearManagerCreateError();
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _jobNumberController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _frController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _poNoController = TextEditingController();
  final _gstNoController = TextEditingController();
  final _doorsController = TextEditingController();
  final _doorLeafController = TextEditingController();
  final _colourShadeController = TextEditingController();
  final _vehicleDetailsController = TextEditingController();

  DateTime? _poDate;
  DateTime? _orderDate;
  DateTime? _deliveryDate;

  @override
  void dispose() {
    _jobNumberController.dispose();
    _companyNameController.dispose();
    _frController.dispose();
    _deliveryAddressController.dispose();
    _poNoController.dispose();
    _gstNoController.dispose();
    _doorsController.dispose();
    _doorLeafController.dispose();
    _colourShadeController.dispose();
    _vehicleDetailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<JobProvider>();
    if (provider.isCreatingManagerJob || !_formKey.currentState!.validate()) {
      return;
    }

    final createdJob = await provider.createManagerJob(
      jobNumber: _jobNumberController.text.trim(),
      companyName: _companyNameController.text.trim(),
      fr: _frController.text.trim().isNotEmpty ? _frController.text.trim() : null,
      deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty ? _deliveryAddressController.text.trim() : null,
      poNo: _poNoController.text.trim().isNotEmpty ? _poNoController.text.trim() : null,
      gstNo: _gstNoController.text.trim().isNotEmpty ? _gstNoController.text.trim() : null,
      poDate: _poDate,
      orderDate: _orderDate,
      deliveryDate: _deliveryDate,
      doors: _doorsController.text.trim().isNotEmpty ? _doorsController.text.trim() : null,
      doorLeaf: _doorLeafController.text.trim().isNotEmpty ? _doorLeafController.text.trim() : null,
      colourShade: _colourShadeController.text.trim().isNotEmpty ? _colourShadeController.text.trim() : null,
      vehicleDetails: _vehicleDetailsController.text.trim().isNotEmpty ? _vehicleDetailsController.text.trim() : null,
    );
    if (!mounted || createdJob == null) {
      return;
    }

    _formKey.currentState!.reset();
    _jobNumberController.clear();
    _companyNameController.clear();
    Navigator.of(context).pop(createdJob);
  }

  String? _requiredValue(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  Future<void> _pickDate(BuildContext context, DateTime? initialDate, ValueChanged<DateTime?> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Widget _buildDateField(String label, DateTime? date, ValueChanged<DateTime?> onPicked, bool isLoading) {
    final dateString = date != null ? date.toIso8601String().split('T').first : 'Select Date';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: InkWell(
        onTap: isLoading ? null : () => _pickDate(context, date, onPicked),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(dateString, style: TextStyle(color: date != null ? null : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isLoading, {bool required = false, Key? fieldKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: !isLoading,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: required ? (value) => _requiredValue(value, label) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final isLoading = provider.isCreatingManagerJob;

    return AppScaffold(
      title: 'Create Job',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'New Manufacturing Job',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          'Enter the job and customer details to begin production.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTheme.space24),
                        _buildTextField(_jobNumberController, 'Job Number', Icons.confirmation_number_outlined, isLoading, required: true, fieldKey: const Key('create-job-number-field')),
                        _buildTextField(_companyNameController, 'Company Name', Icons.business_outlined, isLoading, required: true, fieldKey: const Key('create-company-name-field')),
                        _buildTextField(_frController, 'FR', Icons.text_snippet_outlined, isLoading),
                        _buildTextField(_deliveryAddressController, 'Delivery Address', Icons.location_on_outlined, isLoading),
                        _buildTextField(_poNoController, 'PO No.', Icons.receipt_outlined, isLoading),
                        _buildTextField(_gstNoController, 'GST No.', Icons.account_balance_outlined, isLoading),
                        _buildDateField('PO Date', _poDate, (date) => setState(() => _poDate = date), isLoading),
                        _buildDateField('Order Date', _orderDate, (date) => setState(() => _orderDate = date), isLoading),
                        _buildDateField('Delivery Date', _deliveryDate, (date) => setState(() => _deliveryDate = date), isLoading),
                        _buildTextField(_doorsController, 'Doors', Icons.door_front_door_outlined, isLoading),
                        _buildTextField(_doorLeafController, 'Door Leaf', Icons.view_sidebar_outlined, isLoading),
                        _buildTextField(_colourShadeController, 'Colour Shade', Icons.color_lens_outlined, isLoading),
                        _buildTextField(_vehicleDetailsController, 'Vehicle Details', Icons.local_shipping_outlined, isLoading),
                        if (provider.managerCreateErrorMessage != null) ...[
                          const SizedBox(height: AppTheme.space16),
                          Text(
                            provider.managerCreateErrorMessage!,
                            style: const TextStyle(color: AppTheme.statusCancelled),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          PrimaryActionButton(
            label: 'Create Job',
            icon: Icons.add_task_outlined,
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
