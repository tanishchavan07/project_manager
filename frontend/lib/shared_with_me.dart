import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'dashboard.dart';
import 'project_details.dart';

class SharedWithMePage extends StatefulWidget {
  const SharedWithMePage({super.key});

  @override
  State<SharedWithMePage> createState() => _SharedWithMePageState();
}

class _SharedWithMePageState extends State<SharedWithMePage> {
  List<Project> _sharedProjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _filterStatus = 'all';
  String _filterPriority = 'all';

  @override
  void initState() {
    super.initState();
    _fetchSharedProjects();
  }

  Future<void> _fetchSharedProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allProjects = await ApiService.getProjects();
      final currentUserId = ApiService.currentUser?.id;

      // Filter ONLY projects where logged-in user is an explicit collaborator and NOT the owner
      final collaboratorProjects = allProjects.where((p) {
        if (currentUserId == null || currentUserId.isEmpty) return false;
        final isCollaborator = p.collaboratorIds.contains(currentUserId);
        final isOwner = p.ownerId == currentUserId;
        return isCollaborator && !isOwner;
      }).toList();

      setState(() {
        _sharedProjects = collaboratorProjects;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load shared projects ($e)';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Project> get _filteredProjects {
    return _sharedProjects.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _filterStatus == 'all' || p.status == _filterStatus;
      final matchesPriority = _filterPriority == 'all' || p.priority == _filterPriority;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not set';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  double _calculateProgress(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 1.0;
      case 'active':
        return 0.6;
      case 'in_progress':
        return 0.5;
      case 'on_hold':
        return 0.3;
      case 'planning':
        return 0.15;
      case 'cancelled':
        return 0.0;
      default:
        return 0.25;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;

    return AppScaffold(
      currentTab: AppNavTab.sharedWithMe,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'SHARED WITH ME',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_sharedProjects.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Projects shared with you by other team members where you have collaborator access.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _fetchSharedProjects,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
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
                          hintText: 'Search shared projects...',
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
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'planning', child: Text('PLANNING')),
                            DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                            DropdownMenuItem(value: 'on_hold', child: Text('ON HOLD')),
                            DropdownMenuItem(value: 'completed', child: Text('COMPLETED')),
                            DropdownMenuItem(value: 'cancelled', child: Text('CANCELLED')),
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
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                            DropdownMenuItem(value: 'low', child: Text('LOW')),
                            DropdownMenuItem(value: 'medium', child: Text('MEDIUM')),
                            DropdownMenuItem(value: 'high', child: Text('HIGH')),
                            DropdownMenuItem(value: 'critical', child: Text('CRITICAL')),
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
              const SizedBox(height: 24),

              // Content Area
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
                                ElevatedButton(
                                  onPressed: _fetchSharedProjects,
                                  child: const Text('Retry Connection'),
                                ),
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
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.folder_shared_outlined,
                                          size: 48,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Shared Projects',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Projects created by other users who have added you as a collaborator will appear here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
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
                                      mainAxisExtent: 260,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final project = filtered[index];
                                      return _buildSharedProjectCard(project);
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

  Widget _buildSharedProjectCard(Project p) {
    final progress = _calculateProgress(p.status);
    final progressPercent = (progress * 100).toInt();

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: p.id)),
        );
        _fetchSharedProjects();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            // Header Row: Title & Badges
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

            // Description
            Text(
              p.description.isNotEmpty ? p.description : 'No description provided.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.3),
            ),
            const Spacer(),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFEEF2FF),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom Meta & Actions Row
            Row(
              children: [
                if (p.category.isNotEmpty) ...[
                  const Icon(Icons.label_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    p.category,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(p.startDate)} - ${_formatDate(p.endDate)}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 13, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        'Owner: ${p.ownerId.length > 8 ? '${p.ownerId.substring(0, 8)}...' : p.ownerId}',
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: p.id)),
                    );
                    _fetchSharedProjects();
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
