import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';

class CollectorProfileScreen extends StatefulWidget {
  @override
  _CollectorProfileScreenState createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  bool isLoading = true;
  String name = '';
  String email = '';
  String phone = '';
  String password = '';

  @override
  void initState() {
    super.initState();
    fetchProfile(); // Fetch profile on initialization
  }

  // Fetch collector profile
  Future<void> fetchProfile() async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/profile'; // Use the collector profile endpoint

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['profile'];
      setState(() {
        name = data['name'];
        email = data['email'];
        phone = data['phone'];
        isLoading = false;
      });
    } else {
      print('Failed to load profile: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile.')),
      );
    }
  }

  // Update collector profile
  Future<void> updateProfile() async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/profile'; // Use the collector profile endpoint

    // Build the request body dynamically, omitting the password if it's empty
    Map<String, dynamic> body = {
      'name': name,
    };
    if (password.isNotEmpty) {
      body['password'] = password;
    }

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } else {
      print('Failed to update profile: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  // Get token from shared preferences
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Show confirmation dialog before updating profile
  Future<void> showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Update'),
          content: const Text('Are you sure you want to save these changes?'), // Modified the content text
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                updateProfile(); // Proceed with updating
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Collector Profile',
          style: TextStyle(color: Colors.white), // Changed the heading text color to white
        ),
        backgroundColor: const Color(0xFF6644C0),
         iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (value) {
                      setState(() {
                        name = value;
                      });
                    },
                    controller: TextEditingController(text: name),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Email'),
                    controller: TextEditingController(text: email),
                    enabled: false, // Disable email field
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Phone'),
                    controller: TextEditingController(text: phone),
                    enabled: false, // Disable phone field
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        password = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (name.isNotEmpty && (password.isEmpty || password.length >= 6)) {
                        showConfirmationDialog(); // Show confirmation before updating
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password should be at least 6 characters long.')),
                        );
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white)), // Button text color changed to white
                    style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF6644C0), // Update button background color
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
