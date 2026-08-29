import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'dashboard.dart';

class NewProjectPage extends StatefulWidget {
  final Project? projectToEdit;

  const NewProjectPage({super.key, this.projectToEdit});

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends State<NewProjectPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;

  String _status = 'planning';
  String _priority = 'medium';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _statuses = ['planning', 'active', 'on_hold', 'completed', 'cancelled'];
  final List<String> _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    final p = widget.projectToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');

    if (p != null) {
      _status = _statuses.contains(p.status) ? p.status : 'planning';
      _priority = _priorities.contains(p.priority) ? p.priority : 'medium';
      if (p.startDate != null) _startDate = DateTime.tryParse(p.startDate!);
      if (p.endDate != null) _endDate = DateTime.tryParse(p.endDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() {
        _errorMessage = 'End date cannot be earlier than start date.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.projectToEdit == null) {
        // Create Project (ownerId is derived from JWT on the backend)
        final result = await ApiService.createProject(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          category: _categoryController.text.trim(),
          status: _status,
          priority: _priority,
          startDate: _startDate?.toUtc().toIso8601String(),
          endDate: _endDate?.toUtc().toIso8601String(),
        );

        if (result['success'] == true) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = result['message']?.toString() ?? 'Failed to create project.';
          });
        }
      } else {
        // Update Project
        final fields = <String, dynamic>{
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'category': _categoryController.text.trim(),
          'status': _status,
          'priority': _priority,
        };
        if (_startDate != null) fields['startDate'] = _startDate!.toUtc().toIso8601String();
        if (_endDate != null) fields['endDate'] = _endDate!.toUtc().toIso8601String();

        final result = await ApiService.updateProject(widget.projectToEdit!.id, fields);
        if (result['success'] == true) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = result['message']?.toString() ?? 'Failed to update project.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving project: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.projectToEdit != null;

    return AppScaffold(
      currentTab: AppNavTab.none,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Update Project Details' : 'Create a New Project',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill in the project information below.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Project Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name *',
                      hintText: 'e.g. Website Redesign',
                      prefixIcon: Icon(Icons.folder_outlined, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Project name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe the goals and scope of this project...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Engineering, Design, Marketing',
                      prefixIcon: Icon(Icons.label_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status and Priority Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.flag_outlined, size: 20),
                          ),
                          items: _statuses.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.replaceAll('_', ' ').toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            prefixIcon: Icon(Icons.bolt_outlined, size: 20),
                          ),
                          items: _priorities.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _priority = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start and End Dates
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                            child: Text(
                              _startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                  : 'Not set',
                              style: TextStyle(
                                color: _startDate != null
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(false),
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              prefixIcon: Icon(Icons.event_outlined, size: 18),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                  : 'Not set',
                              style: TextStyle(
                                color: _endDate != null
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEditing ? 'Save Changes' : 'Create Project'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
