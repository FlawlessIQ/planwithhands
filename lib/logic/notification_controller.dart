// import '../data/repositories/notification_repository.dart';

// final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

// final notificationControllerProvider = StateNotifierProvider<NotificationController, NotificationState>((ref) {
//   final repo = ref.watch(notificationRepositoryProvider);
//   return NotificationController(repo);
// });

// class NotificationController extends StateNotifier<NotificationState> {
//   final NotificationRepository repository;
//   NotificationController(this.repository) : super(const NotificationSuccess());

  // Future<void> sendNotification({
  //   required String recipientId,
  //   required String title,
  //   required String body,
  //   String? groupId,
  // }) async {
  //   state = const NotificationLoading();
  //   try {
  //     // determine organizationId for current user
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) throw Exception('User not signed in');
  //     final userDoc = await repository.firestore
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();
  //     final orgId = userDoc.data()?['organizationId'] as String?;
  //     if (orgId == null) throw Exception('OrganizationId not found');
  //     await repository.sendNotification(
  //       orgId: orgId,
  //       recipientId: recipientId,
  //       title: title,
  //       body: body,
  //       groupId: groupId,
  //     );
  //     state = const NotificationSuccess();
  //   } catch (e) {
  //     state = NotificationError(e.toString());
  //   }
  // }

  // Future<void> markAsRead(String notificationId) async {
  //   try {
  //     await repository.markAsRead(notificationId);
  //   } catch (e) {
  //     // Optionally handle error
  //   }
  // }
// }
