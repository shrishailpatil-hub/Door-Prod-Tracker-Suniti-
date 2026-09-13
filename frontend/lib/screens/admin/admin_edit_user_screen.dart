import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/auth/user_role.dart';
import '../../providers/admin_user_provider.dart';
import '../../widgets/common/app_scaffold.dart';

class AdminEditUserScreen extends StatefulWidget {
  const AdminEditUserScreen({super.key});

  @override
  State<AdminEditUserScreen> createState() => _AdminEditUserScreenState();
}

class _AdminEditUserScreenState extends State<AdminEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _userId;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    // Retrieve the user id from route arguments
    final args = ModalRoute.of(context)!.settings.arguments as String;
    _userId = args;
    final provider = Provider.of<AdminUserProvider>(context, listen: false);
    final user = provider.users.firstWhere((u) => u.id == _userId);
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _selectedRole = user.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = Provider.of<AdminUserProvider>(context, listen: false);
    await provider.updateUser(
      id: _userId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      role: _selectedRole!,
    );
    if (provider.updateErrorMessage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
      Navigator.of(context).pop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.updateErrorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminUserProvider>(context);
    return AppScaffold(
      title: 'Edit User',
      showBackButton: true,
      padding: EdgeInsets.all(AppTheme.space16),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.isEmpty) ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: AppTheme.space12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Email cannot be empty';
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                return emailRegex.hasMatch(value) ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: AppTheme.space12),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: UserRole.values
                  .map((role) => DropdownMenuItem(value: role, child: Text(role.displayName)))
                  .toList(),
              onChanged: (role) => setState(() => _selectedRole = role),
              validator: (value) => value == null ? 'Please select a role' : null,
            ),
            const SizedBox(height: AppTheme.space24),
            ElevatedButton(
              onPressed: provider.isUpdating ? null : _submit,
              child: provider.isUpdating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
