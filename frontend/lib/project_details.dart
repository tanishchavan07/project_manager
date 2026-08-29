import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'new_project.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Project? _project;
  List<Task> _tasks = [];
  List<Milestone> _milestones = [];
  List<Comment> _comments = [];
  List<User> _collaborators = [];

  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllProjectData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProjectData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await ApiService.getProject(widget.projectId);
      final t = await ApiService.getTasks(widget.projectId);
      final m = await ApiService.getMilestones(widget.projectId);
      final c = await ApiService.getComments(widget.projectId);
      final col = await ApiService.getCollaborators(widget.projectId);

      setState(() {
        _project = p;
        _tasks = t;
        _milestones = m;
        _comments = c;
        _collaborators = col;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading project details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // TASK ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _showTaskDialog({Task? taskToEdit}) async {
    final isEdit = taskToEdit != null;
    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    final descController = TextEditingController(text: taskToEdit?.description ?? '');
    final assignController = TextEditingController(text: taskToEdit?.assignedTo ?? '');
    String status = taskToEdit?.status ?? 'todo';
    String priority = taskToEdit?.priority ?? 'medium';
    DateTime? dueDate = taskToEdit?.dueDate != null ? DateTime.tryParse(taskToEdit!.dueDate!) : null;

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Task' : 'Add New Task'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Task Title *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['todo', 'in_progress', 'in_review', 'done', 'cancelled'].map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => status = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: ['low', 'medium', 'high', 'critical'].map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => priority = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: assignController,
                    decoration: const InputDecoration(labelText: 'Assigned User', hintText: 'Name or email'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : 'Not set',
                        style: TextStyle(color: dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isEdit) {
                    final fields = <String, dynamic>{
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'status': status,
                      'priority': priority,
                    };
                    if (dueDate != null) fields['dueDate'] = dueDate!.toUtc().toIso8601String();
                    if (assignController.text.isNotEmpty) {
                      fields['assignedTo'] = assignController.text.trim();
                    }
                    await ApiService.updateTask(taskToEdit.id, fields);
                  } else {
                    await ApiService.createTask(
                      projectId: widget.projectId,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      status: status,
                      priority: priority,
                      dueDate: dueDate?.toUtc().toIso8601String(),
                      assignedTo: assignController.text.trim().isNotEmpty ? assignController.text.trim() : null,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Task'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updatedTasks = await ApiService.getTasks(widget.projectId);
      setState(() => _tasks = updatedTasks);
    }
  }

  Future<void> _toggleTaskStatus(Task task) async {
    final newStatus = task.status == 'done' ? 'todo' : 'done';
    try {
      await ApiService.updateTask(task.id, {'status': newStatus});
      final updatedTasks = await ApiService.getTasks(widget.projectId);
      setState(() => _tasks = updatedTasks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteTask(task.id);
        final updated = await ApiService.getTasks(widget.projectId);
        setState(() => _tasks = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MILESTONE ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _showMilestoneDialog({Milestone? milestoneToEdit}) async {
    final isEdit = milestoneToEdit != null;
    final titleController = TextEditingController(text: milestoneToEdit?.title ?? '');
    final descController = TextEditingController(text: milestoneToEdit?.description ?? '');
    String status = milestoneToEdit?.status ?? 'pending';
    DateTime? dueDate = milestoneToEdit?.dueDate != null ? DateTime.tryParse(milestoneToEdit!.dueDate!) : null;

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Milestone' : 'Add New Milestone'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Milestone Title *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['pending', 'in_progress', 'completed', 'missed'].map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => status = v!),
                    ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : 'Not set',
                        style: TextStyle(color: dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isEdit) {
                    final fields = <String, dynamic>{
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'status': status,
                    };
                    if (dueDate != null) fields['dueDate'] = dueDate!.toUtc().toIso8601String();
                    await ApiService.updateMilestone(milestoneToEdit.id, fields);
                  } else {
                    await ApiService.createMilestone(
                      projectId: widget.projectId,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      status: status,
                      dueDate: dueDate?.toUtc().toIso8601String(),
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Milestone'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updated = await ApiService.getMilestones(widget.projectId);
      setState(() => _milestones = updated);
    }
  }

  Future<void> _deleteMilestone(Milestone milestone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: Text('Are you sure you want to delete "${milestone.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteMilestone(milestone.id);
        final updated = await ApiService.getMilestones(widget.projectId);
        setState(() => _milestones = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // COMMENTS / DISCUSSION ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      final res = await ApiService.addComment(
        projectId: widget.projectId,
        message: text,
      );
      if (res['success'] == true) {
        _commentController.clear();
        final updated = await ApiService.getComments(widget.projectId);
        setState(() => _comments = updated);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to add comment')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteComment(comment.id);
        final updated = await ApiService.getComments(widget.projectId);
        setState(() => _comments = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // COLLABORATOR ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _showAddCollaboratorDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Collaborator'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the email address of the registered user to add as a collaborator.',
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final res = await ApiService.addCollaborator(widget.projectId, emailController.text.trim());
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
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true) {
      final updated = await ApiService.getCollaborators(widget.projectId);
      setState(() => _collaborators = updated);
    }
  }

  Future<void> _removeCollaborator(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text('Remove ${user.name} from project collaborators?'),
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
        await ApiService.removeCollaborator(widget.projectId, user.id);
        final updated = await ApiService.getCollaborators(widget.projectId);
        setState(() => _collaborators = updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PROJECT DELETE / EDIT
  // ---------------------------------------------------------------------------

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project? All associated tasks, milestones, and comments will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteProject(widget.projectId);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AI CHAT HELPER
  // ---------------------------------------------------------------------------

  void _openAIChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AIChatModal(projectId: widget.projectId, projectName: _project?.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Project not found', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadAllProjectData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _project!;
    final totalTasks = _tasks.length;
    final doneTasks = _tasks.where((t) => t.status == 'done').length;
    final progress = totalTasks > 0 ? (doneTasks / totalTasks) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined, color: Color(0xFF4F46E5)),
            tooltip: 'Ask AI about this project',
            onPressed: _openAIChat,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Project',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => NewProjectPage(projectToEdit: p)),
              );
              if (updated == true) _loadAllProjectData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            tooltip: 'Delete Project',
            onPressed: _deleteProject,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Project Overview Header Card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildBadge(p.status.toUpperCase(), const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                                  const SizedBox(width: 8),
                                  _buildBadge(p.priority.toUpperCase(), const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
                                ],
                              ),
                              if (p.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  p.description,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  if (p.category.isNotEmpty)
                                    _buildInfoChip(Icons.category_outlined, p.category),
                                  if (p.startDate != null)
                                    _buildInfoChip(Icons.calendar_today_outlined, 'Start: ${p.startDate!.split('T')[0]}'),
                                  if (p.endDate != null)
                                    _buildInfoChip(Icons.event_outlined, 'End: ${p.endDate!.split('T')[0]}'),
                                  _buildInfoChip(Icons.people_outline, '${_collaborators.length} Collaborators'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Task Progress',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                            ),
                            Text(
                              '$doneTasks of $totalTasks completed (${(progress * 100).toInt()}%)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF4F46E5),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.check_circle_outline, size: 18), text: 'Tasks (${_tasks.length})'),
                    Tab(icon: const Icon(Icons.flag_outlined, size: 18), text: 'Milestones (${_milestones.length})'),
                    Tab(icon: const Icon(Icons.chat_bubble_outline, size: 18), text: 'Discussion (${_comments.length})'),
                    Tab(icon: const Icon(Icons.group_outlined, size: 18), text: 'Team (${_collaborators.length})'),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTasksTab(),
                    _buildMilestonesTab(),
                    _buildCommentsTab(),
                    _buildCollaboratorsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildTasksTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Project Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showTaskDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Task'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tasks.isEmpty
                ? _buildEmptyState('No tasks created yet.', 'Add actionable tasks to track project progress.', Icons.task_alt)
                : ListView.separated(
                    itemCount: _tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final isDone = task.status == 'done';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isDone,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (_) => _toggleTaskStatus(task),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      task.description,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildBadge(task.status.toUpperCase(), const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                                      _buildBadge(task.priority.toUpperCase(), const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                                      if (task.dueDate != null)
                                        _buildInfoChip(Icons.calendar_today, task.dueDate!.split('T')[0]),
                                      if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                                        _buildInfoChip(Icons.person_outline, task.assignedTo!),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showTaskDialog(taskToEdit: task),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                              onPressed: () => _deleteTask(task),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Project Milestones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showMilestoneDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Milestone'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _milestones.isEmpty
                ? _buildEmptyState('No milestones defined yet.', 'Add milestones to track critical goals and phases.', Icons.flag_outlined)
                : ListView.separated(
                    itemCount: _milestones.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final m = _milestones[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.flag, color: Color(0xFF4F46E5), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        m.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildBadge(m.status.toUpperCase(), const Color(0xFF10B981), const Color(0xFFECFDF5)),
                                    ],
                                  ),
                                  if (m.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(m.description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                  ],
                                  if (m.dueDate != null) ...[
                                    const SizedBox(height: 6),
                                    _buildInfoChip(Icons.event, 'Target: ${m.dueDate!.split('T')[0]}'),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showMilestoneDialog(milestoneToEdit: m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                              onPressed: () => _deleteMilestone(m),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Comment Composer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Share an update or comment on this project...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isPostingComment ? null : _postComment,
                  child: _isPostingComment
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Comments Feed
          Expanded(
            child: _comments.isEmpty
                ? _buildEmptyState('No discussion comments yet.', 'Start the conversation by posting the first comment.', Icons.chat_bubble_outline)
                : ListView.separated(
                    itemCount: _comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFEEF2FF),
                              child: const Icon(Icons.person, size: 18, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'User: ${comment.userId.substring(0, comment.userId.length > 8 ? 8 : comment.userId.length)}...',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (comment.createdAt != null)
                                        Text(
                                          comment.createdAt!.split('T')[0],
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.message,
                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () => _deleteComment(comment),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Project Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddCollaboratorDialog,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add Collaborator'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _collaborators.isEmpty
                ? _buildEmptyState('No collaborators added.', 'Click "Add Collaborator" to invite team members by User ID.', Icons.people_outline)
                : ListView.separated(
                    itemCount: _collaborators.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _collaborators[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(user.email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  Text('ID: ${user.id}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626)),
                              onPressed: () => _removeCollaborator(user),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ],
    );
  }
}

// =============================================================================
// AI ASSISTANT CHAT MODAL
// =============================================================================

class _AIChatModal extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const _AIChatModal({this.projectId, this.projectName});

  @override
  State<_AIChatModal> createState() => _AIChatModalState();
}

class _AIChatModalState extends State<_AIChatModal> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'text': widget.projectName != null
          ? 'Hello! I am your AI project assistant for "${widget.projectName}". Ask me anything about pending tasks, deadlines, or project summaries!'
          : 'Hello! I am your AI project assistant. How can I assist you with your projects today?',
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? quickPrompt]) async {
    final text = quickPrompt ?? _msgController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _msgController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    try {
      final res = await ApiService.sendAIMessage(message: text, projectId: widget.projectId);
      if (res['success'] == true && res['data'] != null) {
        final reply = res['data']['reply']?.toString() ?? 'No response received.';
        setState(() {
          _messages.add({'role': 'ai', 'text': reply});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': '⚠️ ${res['message']?.toString() ?? 'Failed to get AI response.'}',
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': '⚠️ Connection error: $e',
        });
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Project Assistant',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.projectName != null ? 'Context: ${widget.projectName}' : 'General Assistant',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Quick Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('What tasks are pending?'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Which task has the highest priority?'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Summarize this project'),
                  const SizedBox(width: 8),
                  _buildQuickChip('What should I work on next?'),
                ],
              ),
            ),
          ),

          // Chat Message List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('AI is analyzing project context...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),

          // Message Composer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Type your question to the AI...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      onPressed: () => _sendMessage(label),
    );
  }
}
