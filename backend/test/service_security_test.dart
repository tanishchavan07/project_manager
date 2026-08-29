import 'package:test/test.dart';
import '../lib/config/database.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/project_service.dart';
import '../lib/services/task_service.dart';
import '../lib/services/milestone_service.dart';
import '../lib/services/comment_service.dart';
import '../lib/services/collaboration_service.dart';

void main() {
  group('Backend Authorization Unit & Service Tests', () {
    late String userAId;
    late String userAEmail;
    late String userBId;
    late String userBEmail;

    late String projectAId;
    late String projectBId;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    setUpAll(() async {
      await Database.connect();

      // 1. Create User A
      userAEmail = 'usera_$timestamp@service.test';
      final resA = await AuthService.register({
        'name': 'User A',
        'email': userAEmail,
        'password': 'password123',
      });
      expect(resA['statusCode'], 201);
      userAId = resA['body']['data']['user']['id'];

      // 2. Create User B
      userBEmail = 'userb_$timestamp@service.test';
      final resB = await AuthService.register({
        'name': 'User B',
        'email': userBEmail,
        'password': 'password123',
      });
      expect(resB['statusCode'], 201);
      userBId = resB['body']['data']['user']['id'];
    });

    tearDownAll(() async {
      await Database.close();
    });

    test('1. User A creates Project A', () async {
      final res = await ProjectService.createProject({
        'name': 'Project Alpha Security Test',
        'description': 'Owned strictly by User A',
        'category': 'Confidential',
        'status': 'active',
        'priority': 'high',
      }, userAId);

      expect(res['statusCode'], 201);
      expect(res['body']['success'], true);
      projectAId = res['body']['data']['id'];
      expect(res['body']['data']['ownerId'], userAId);
    });

    test('2. User B calls getAllProjects() -> Project A is NOT returned', () async {
      final res = await ProjectService.getAllProjects(userBId);
      expect(res['statusCode'], 200);
      final List projects = res['body']['data'];
      final containsProjectA = projects.any((p) => p['id'] == projectAId);
      expect(containsProjectA, isFalse);
    });

    test('3. User B creates Project B', () async {
      final res = await ProjectService.createProject({
        'name': 'Project Beta Security Test',
        'description': 'Owned by User B',
        'category': 'Finance',
        'status': 'planning',
        'priority': 'medium',
      }, userBId);

      expect(res['statusCode'], 201);
      projectBId = res['body']['data']['id'];
      expect(res['body']['data']['ownerId'], userBId);
    });

    test('4. User B calls getAllProjects() -> ONLY Project B is returned', () async {
      final res = await ProjectService.getAllProjects(userBId);
      expect(res['statusCode'], 200);
      final List projects = res['body']['data'];
      expect(projects.length, 1);
      expect(projects[0]['id'], projectBId);
      expect(projects[0]['name'], 'Project Beta Security Test');
    });

    test('5. User B tries to access Project A directly -> returns 403 Forbidden', () async {
      final res = await ProjectService.getProjectById(projectAId, userBId);
      expect(res['statusCode'], 403);
      expect(res['body']['success'], false);
      expect(res['body']['message'], contains('not authorized'));
    });

    test('6. User B tries to update Project A directly -> returns 403 Forbidden', () async {
      final res = await ProjectService.updateProject(projectAId, {
        'name': 'Unauthorized Title',
      }, userBId);
      expect(res['statusCode'], 403);
      expect(res['body']['success'], false);
    });

    test('7. User B tries to delete Project A directly -> returns 403 Forbidden', () async {
      final res = await ProjectService.deleteProject(projectAId, userBId);
      expect(res['statusCode'], 403);
      expect(res['body']['success'], false);
    });

    test('8. User B tries to create a task in Project A -> returns 403 Forbidden', () async {
      final res = await TaskService.createTask({
        'projectId': projectAId,
        'title': 'Hacker Task',
      }, userBId);
      expect(res['statusCode'], 403);
    });

    test('9. User B tries to list tasks in Project A -> returns 403 Forbidden', () async {
      final res = await TaskService.getTasksByProject(projectAId, userBId);
      expect(res['statusCode'], 403);
    });

    test('10. User B tries to add milestone in Project A -> returns 403 Forbidden', () async {
      final res = await MilestoneService.createMilestone({
        'projectId': projectAId,
        'title': 'Unauthorized Milestone',
      }, userBId);
      expect(res['statusCode'], 403);
    });

    test('11. User B tries to add comment in Project A -> returns 403 Forbidden', () async {
      final res = await CommentService.addComment(projectAId, {
        'message': 'Unauthorized Comment',
      }, userBId);
      expect(res['statusCode'], 403);
    });

    test('12. User A can access, view, update Project A', () async {
      final res = await ProjectService.getProjectById(projectAId, userAId);
      expect(res['statusCode'], 200);
      expect(res['body']['data']['id'], projectAId);
    });

    test('13. User A adds User B as collaborator -> User B can now collaborate on Project A', () async {
      final addCollab = await CollaborationService.addCollaborator(
        projectAId,
        {'email': userBEmail},
        userAId,
      );
      expect(addCollab['statusCode'], 200);

      // User B can now view Project A
      final viewRes = await ProjectService.getProjectById(projectAId, userBId);
      expect(viewRes['statusCode'], 200);
      expect(viewRes['body']['data']['id'], projectAId);

      // User B can create a task in Project A
      final taskRes = await TaskService.createTask({
        'projectId': projectAId,
        'title': 'Collaborator Task',
        'status': 'todo',
        'priority': 'medium',
      }, userBId);
      expect(taskRes['statusCode'], 201);

      // User B can post a comment in Project A
      final commentRes = await CommentService.addComment(projectAId, {
        'message': 'Collaborator feedback message',
      }, userBId);
      expect(commentRes['statusCode'], 201);
    });

    test('14. User B calls getAllProjects() -> returns both Project B (owned) and Project A (shared)', () async {
      final res = await ProjectService.getAllProjects(userBId);
      expect(res['statusCode'], 200);
      final List projects = res['body']['data'];
      expect(projects.length, 2);
      final ids = projects.map((p) => p['id']).toList();
      expect(ids, containsAll([projectAId, projectBId]));
    });
  });
}
