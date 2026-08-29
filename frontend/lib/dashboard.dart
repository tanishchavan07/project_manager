import 'package:flutter/material.dart';
import 'api_service.dart';
import 'collaboration.dart';
import 'login.dart';
import 'new_project.dart';
import 'project_details.dart';
import 'shared_with_me.dart';

// =============================================================================
// SHARED NAVIGATION SHELL / SCAFFOLD
// =============================================================================

enum AppNavTab { dashboard, sharedWithMe, collaboration, none }

class AppScaffold extends StatelessWidget {
  final Widget body;
  final AppNavTab currentTab;
  final String? activeProjectId;
  final String? activeProjectName;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    this.currentTab = AppNavTab.none,
    this.activeProjectId,
    this.activeProjectName,
    this.floatingActionButton,
  });

  void _showProfilePopup(BuildContext context) {
    final user = ApiService.currentUser;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEEF2FF),
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('User Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('Name', user?.name ?? 'Unknown User'),
            const SizedBox(height: 10),
            _buildProfileItem('Email', user?.email ?? 'Not available'),
            const SizedBox(height: 10),
            _buildProfileItem('User ID', user?.id ?? 'Not available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
            onPressed: () {
              ApiService.logout();
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _openAIChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AIChatModal(
        projectId: activeProjectId,
        projectName: activeProjectName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SafeArea(
            child: Row(
              children: [
                // Left: Logo & App Name
                InkWell(
                  onTap: () {
                    if (currentTab != AppNavTab.dashboard) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardPage()),
                        (route) => false,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: Color(0xFF4F46E5),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ProjectFlow AI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // Navigation Items
                _buildNavItem(
                  context,
                  title: 'Dashboard',
                  icon: Icons.grid_view_rounded,
                  isActive: currentTab == AppNavTab.dashboard,
                  onTap: () {
                    if (currentTab != AppNavTab.dashboard) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildNavItem(
                  context,
                  title: 'Shared With Me',
                  icon: Icons.folder_shared_outlined,
                  isActive: currentTab == AppNavTab.sharedWithMe,
                  onTap: () {
                    if (currentTab != AppNavTab.sharedWithMe) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SharedWithMePage()),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildNavItem(
                  context,
                  title: 'Collaboration / Team',
                  icon: Icons.group_outlined,
                  isActive: currentTab == AppNavTab.collaboration,
                  onTap: () {
                    if (currentTab != AppNavTab.collaboration) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CollaborationPage()),
                      );
                    }
                  },
                ),

                const Spacer(),

                // Right: AI Chat Button
                ElevatedButton.icon(
                  onPressed: () => _openAIChat(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2FF),
                    foregroundColor: const Color(0xFF4F46E5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(width: 14),

                // Right: Profile Avatar Icon
                InkWell(
                  onTap: () => _showProfilePopup(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DASHBOARD PAGE
// =============================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _filterStatus = 'all';
  String _filterPriority = 'all';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getProjects();
      setState(() {
        _projects = list;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load projects from server ($e)';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Project> get _filteredProjects {
    final currentUserId = ApiService.currentUser?.id;
    return _projects.where((p) {
      // Must only show projects created by the logged-in user
      if (currentUserId != null && currentUserId.isNotEmpty && p.ownerId != currentUserId) {
        return false;
      }

      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _filterStatus == 'all' || p.status == _filterStatus;
      final matchesPriority = _filterPriority == 'all' || p.priority == _filterPriority;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();
  }

  Future<void> _deleteProject(Project p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${p.name}" and all its tasks?'),
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
        await ApiService.deleteProject(p.id);
        _fetchProjects();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;

    return AppScaffold(
      currentTab: AppNavTab.dashboard,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner & Quick Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${ApiService.currentUser?.name ?? "User"} 👋',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage your active projects, tasks, milestones and team collaboration.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const NewProjectPage()),
                      );
                      if (created == true) _fetchProjects();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Project'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter & Search Toolbar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search Input
                    SizedBox(
                      width: 320,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search projects by name, category...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),

                    // Status Dropdown Filter
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Status: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        DropdownButton<String>(
                          value: _filterStatus,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                            const DropdownMenuItem(value: 'planning', child: Text('PLANNING')),
                            const DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                            const DropdownMenuItem(value: 'on_hold', child: Text('ON HOLD')),
                            const DropdownMenuItem(value: 'completed', child: Text('COMPLETED')),
                            const DropdownMenuItem(value: 'cancelled', child: Text('CANCELLED')),
                          ],
                          onChanged: (v) => setState(() => _filterStatus = v!),
                        ),
                      ],
                    ),

                    // Priority Dropdown Filter
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Priority: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        DropdownButton<String>(
                          value: _filterPriority,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                            const DropdownMenuItem(value: 'low', child: Text('LOW')),
                            const DropdownMenuItem(value: 'medium', child: Text('MEDIUM')),
                            const DropdownMenuItem(value: 'high', child: Text('HIGH')),
                            const DropdownMenuItem(value: 'critical', child: Text('CRITICAL')),
                          ],
                          onChanged: (v) => setState(() => _filterPriority = v!),
                        ),
                      ],
                    ),

                    // Reset Filters
                    if (_searchQuery.isNotEmpty || _filterStatus != 'all' || _filterPriority != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterStatus = 'all';
                            _filterPriority = 'all';
                          });
                        },
                        child: const Text('Reset Filters'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header: MY PROJECTS
              Row(
                children: [
                  const Text(
                    'MY PROJECTS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${filtered.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content Area: Grid / Empty / Error / Loading
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFDC2626)),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(fontSize: 15, color: Color(0xFF475569))),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _fetchProjects, child: const Text('Retry Connection')),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(48),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.folder_open_outlined, size: 56, color: Color(0xFF94A3B8)),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No projects found.',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Get started by creating your first project now.',
                                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final created = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(builder: (_) => const NewProjectPage()),
                                          );
                                          if (created == true) _fetchProjects();
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Create New Project'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 800;
                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isWide ? 2 : 1,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: 220,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final project = filtered[index];
                                      return _buildProjectCard(project);
                                    },
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

  Widget _buildProjectCard(Project p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 8),
              _buildBadge(p.status.toUpperCase(), const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
              const SizedBox(width: 6),
              _buildBadge(p.priority.toUpperCase(), const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              p.description.isNotEmpty ? p.description : 'No description provided.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.3),
            ),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              if (p.category.isNotEmpty) ...[
                const Icon(Icons.label_outline, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(p.category, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(width: 14),
              ],
              const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('${p.collaboratorIds.length} Team', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const Spacer(),
              // Actions
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => NewProjectPage(projectToEdit: p)),
                  );
                  if (updated == true) _fetchProjects();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                tooltip: 'Delete',
                onPressed: () => _deleteProject(p),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: p.id)),
                  );
                  _fetchProjects();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
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
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// =============================================================================
// AI ASSISTANT CHAT MODAL
// =============================================================================

class AIChatModal extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const AIChatModal({super.key, this.projectId, this.projectName});

  @override
  State<AIChatModal> createState() => _AIChatModalState();
}

class _AIChatModalState extends State<AIChatModal> {
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
                        widget.projectName != null ? 'Context: ${widget.projectName}' : 'General Project Assistant',
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
                  _buildQuickChip('Which task has highest priority?'),
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
