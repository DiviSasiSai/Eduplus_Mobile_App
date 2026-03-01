import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat.dart';
import 'package:firebase_core/firebase_core.dart';

/// ----------------------------------------------------
/// APP START
/// ----------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  final regNo = prefs.getString("reg_no");
  final deviceId = prefs.getString("device_id");

  runApp(
    EduplusApp(
      isLoggedIn: isLoggedIn,
      regNo: regNo,
      deviceId: deviceId,
    ),
  );
}



/// ----------------------------------------------------
/// ROOT APP
/// ----------------------------------------------------
class EduplusApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? regNo;
  final String? deviceId;

  const EduplusApp({
    super.key,
    required this.isLoggedIn,
    this.regNo,
    this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn && regNo != null && deviceId != null
          ? ChatScreen(regNo: regNo!, deviceId: deviceId!)
          : const LoginScreen(),
    );
  }
}

/// ----------------------------------------------------
/// LOGIN SCREEN
/// ----------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final regCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String error = "";
  bool loading = false;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = "";
    });

    final res = await http.post(
      Uri.parse(
          "https://colorable-faith-rancorously.ngrok-free.dev/login"),
      body: {
        "reg_no": regCtrl.text.trim(),
        "password": passCtrl.text.trim(),
      },
    );

    final data = json.decode(res.body);

    if (data["status"] == "success") {
      /// 🔐 SAVE LOGIN SESSION
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isLoggedIn", true);
      await prefs.setString("reg_no", data["reg_no"]);
      await prefs.setString("device_id", data["device_id"]);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            regNo: data["reg_no"],
            deviceId: data["device_id"],
          ),
        ),
      );
    } else {
      setState(() {
        error = data["message"];
      });
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Eduplus Login",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: regCtrl,
                  decoration:
                      const InputDecoration(labelText: "Reg No"),
                ),

                TextField(
                  controller: passCtrl,
                  decoration:
                      const InputDecoration(labelText: "DOB"),
                  obscureText: true,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("LOGIN"),
                  ),
                ),

                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.red),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
