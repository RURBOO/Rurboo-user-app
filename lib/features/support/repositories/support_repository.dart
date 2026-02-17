import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class SupportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTicket(TicketModel ticket) async {
    await _firestore
        .collection('support_tickets')
        .doc(ticket.id)
        .set(ticket.toJson());
  }

  Stream<List<TicketModel>> getUserTickets(String userId) {
    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TicketModel.fromJson(doc.data()))
            .toList());
  }
}
