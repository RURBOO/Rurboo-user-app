import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream messages for a specific ride
  Stream<QuerySnapshot> getMessages(String rideId) {
    return _firestore
        .collection('rideRequests')
        .doc(rideId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Send a new message
  Future<void> sendMessage(String rideId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('rideRequests')
        .doc(rideId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User', // You might want to pass this if available
      'timestamp': FieldValue.serverTimestamp(),
      'isDriver': false, // Differentiate sender
    });
  }
}
