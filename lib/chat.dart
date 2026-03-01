import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // for LoginScreen navigation
import 'package:firebase_messaging/firebase_messaging.dart';


class ChatScreen extends StatefulWidget {
  final String regNo;
  final String deviceId;

  const ChatScreen({super.key, required this.regNo, required this.deviceId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final List<Map> messages = [];
  late WebSocketChannel channel;
  
  /// 🔹 SAVE CHAT LOCALLY
  Future<void> saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      "chat_${widget.deviceId}",
      jsonEncode(messages),
    );
  }

  /// 🔹 LOAD CHAT ON APP REOPEN
  Future<void> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("chat_${widget.deviceId}");

    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        messages.addAll(decoded.cast<Map>());
      });
    }
  }

  Future<void> setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();

      if (token != null) {
        await http.post(
          Uri.parse(
            "https://colorable-faith-rancorously.ngrok-free.dev/save-fcm",
          ),
          body: {
            "reg_no": widget.regNo,
            "device_id": widget.deviceId,
            "fcm_token": token,
          },
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    loadMessages(); // ✅ RESTORE CHAT
    setupFCM();

    channel = WebSocketChannel.connect(
      Uri.parse(
        "wss://colorable-faith-rancorously.ngrok-free.dev/ws/${widget.deviceId}",
      ),
    );

    channel.stream.listen((data) {
      final msg = json.decode(data);
      setState(() {
        messages.add({"from": "ai", "text": msg["message"]});
      });
      saveMessages(); // ✅ SAVE AFTER AI MESSAGE
    });
  }


  /// ✅ Close socket & controller safely
  @override
  void dispose() {
    channel.sink.close();
    msgCtrl.dispose();
    super.dispose();
  }

  /// 🔹 GROUP NAME LOGIC
  String getGroupName() {
    final reg = widget.regNo.toLowerCase();
    if (reg.contains("cs")) {
      return "CSE_VIII_SEM_2025-2026";
    } else if (reg.contains("ec")) {
      return "ECE_VIII_SEM_2025-2026";
    }
    return "UNKNOWN_GROUP";
  }

  /// 🔹 USER INFO BOTTOM SHEET
  void showUserInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "User Info",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(Icons.badge),
                  const SizedBox(width: 8),
                  Text("Reg No: ${widget.regNo}"),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.group),
                  const SizedBox(width: 8),
                  Text("Group: ${getGroupName()}"),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),

              /// 🔴 LOGOUT
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove("chat_${widget.deviceId}"); // ✅ CLEAR CHAT
                  await http.post(
                    Uri.parse("https://colorable-faith-rancorously.ngrok-free.dev/logout"),
                    body: {
                      "reg_no": widget.regNo,
                    },
                  );

                  Navigator.pop(context);

                  // close websocket
                  await channel.sink.close();

                  // clear saved login
                  await prefs.clear();

                  // navigate to login
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔹 SEND MESSAGE
  void sendMessage() async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"from": "user", "text": text});
    });

    msgCtrl.clear();
    saveMessages(); // ✅

    await http.post(
      Uri.parse(
        "https://colorable-faith-rancorously.ngrok-free.dev/user-message",
      ),
      body: {
        "device_id": widget.deviceId,
        "reg_no": widget.regNo,
        "message": text
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text("Eduplus AI"),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: showUserInfo,
          ),
        ],
      ),

      body: Column(
        children: [
          /// CHAT AREA
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isUser = m["from"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFFDCF8C6)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight:
                            isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      m["text"],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          /// INPUT BAR
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      decoration: InputDecoration(
                        hintText: "Send a message",
                        filled: true,
                        fillColor: const Color(0xFFF0F0F0),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: sendMessage,
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        "Send",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
