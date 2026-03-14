import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../../language/viewmodels/language_vm.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String driverName;

  const ChatScreen({super.key, required this.rideId, required this.driverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ChatService _chatService = ChatService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  void _send() {
    if (_msgController.text.trim().isEmpty) return;
    _chatService.sendMessage(widget.rideId, _msgController.text.trim());
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.driverName}"),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.rideId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text(lang.getText('uiNoMessages')));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          data['text'] ?? "",
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _send,
                    child: const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
