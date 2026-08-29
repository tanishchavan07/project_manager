import 'package:flutter/material.dart';
import 'api_service.dart';
import 'dashboard.dart';

class CollaborationPage extends StatefulWidget {
  final String? initialProjectId;

  const CollaborationPage({super.key, this.initialProjectId});

  @override
  State<CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<CollaborationPage> {
  List<Project> _projects = [];
  String? _selectedProjectId;
  List<User> _collaborators = [];

  bool _isLoadingProjects = true;
  bool _isLoadingCollaborators = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getProjects();
      setState(() {
        _projects = list;
        if (_projects.isNotEmpty) {
          _selectedProjectId = widget.initialProjectId ?? _projects.first.id;
        }
      });
      if (_selectedProjectId != null) {
        await _loadCollaborators(_selectedProjectId!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load projects: $e';
      });
    } finally {
      setState(() {
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadCollaborators(String projectId) async {
    setState(() {
      _isLoadingCollaborators = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getCollaborators(projectId);
      setState(() {
        _collaborators = list;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load collaborators: $e';
      });
    } finally {
      setState(() {
        _isLoadingCollaborators = false;
      });
    }
  }

  Future<void> _showAddCollaboratorDialog() async {
    if (_selectedProjectId == null) return;
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Team Collaborator'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the email address of the registered user you wish to add to this project.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'User Email *',
                  hintText: 'member@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final res = await ApiService.addCollaborator(
                  _selectedProjectId!,
                  emailController.text.trim(),
                );
                if (res['success'] == true) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } else {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Failed to add collaborator'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('Add Collaborator'),
          ),
        ],
      ),
    );

    if (added == true && _selectedProjectId != null) {
      _loadCollaborators(_selectedProjectId!);
    }
  }

  Future<void> _confirmRemoveCollaborator(User user) async {
    if (_selectedProjectId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text('Are you sure you want to remove ${user.name} (${user.email}) from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.removeCollaborator(_selectedProjectId!, user.id);
        if (res['success'] == true) {
          _loadCollaborators(_selectedProjectId!);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Failed to remove collaborator'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentTab: AppNavTab.collaboration,
      body: _isLoadingProjects
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Project Selector Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_shared_outlined, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 12),
                          const Text(
                            'Select Project:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _projects.isEmpty
                                ? const Text('No projects available')
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedProjectId,
                                      isExpanded: true,
                                      items: _projects.map((p) {
                                        return DropdownMenuItem(
                                          value: p.id,
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedProjectId = val);
                                          _loadCollaborators(val);
                                        }
                                      },
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _projects.isEmpty ? null : _showAddCollaboratorDialog,
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: const Text('Add Collaborator'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626))),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Collaborators List
                    Expanded(
                      child: _isLoadingCollaborators
                          ? const Center(child: CircularProgressIndicator())
                          : _collaborators.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(48),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.group_outlined,
                                        size: 48,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No collaborators added to this project yet.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Click "Add Collaborator" above to invite team members using their User ID.',
                                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _collaborators.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final user = _collaborators[index];
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFFEEF2FF),
                                            child: Text(
                                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                              style: const TextStyle(
                                                color: Color(0xFF4F46E5),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  user.email,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'ID: ${user.id}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626)),
                                            tooltip: 'Remove Collaborator',
                                            onPressed: () => _confirmRemoveCollaborator(user),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
