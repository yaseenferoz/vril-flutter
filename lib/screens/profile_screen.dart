import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';

class VendorProfileScreen extends StatefulWidget {
  @override
  _VendorProfileScreenState createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  bool isLoading = true;
  String name = '';
  String email = '';
  String phone = '';
  String password = '';

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  // Fetch vendor profile
  Future<void> fetchProfile() async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/profile';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['profile']; // Access 'profile' key
      setState(() {
        name = data['name'];
        email = data['email'];
        phone = data['phone'];
        isLoading = false;
      });
    } else {
      print('Failed to load profile: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile.')),
      );
    }
  }

  // Update vendor profile
  Future<void> updateProfile() async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/profile';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'password': password.isNotEmpty ? password : null, // Update only if password is not empty
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully.')));
    } else {
      print('Failed to update profile: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile.')));
    }
  }

  // Get token from shared preferences
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Show confirmation dialog
  Future<void> showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Update'),
          content: Text('Are you sure you want to update the profile?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                updateProfile(); // Proceed with updating
              },
              child: Text('Confirm'),
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
        title: Text('Profile', style: TextStyle(
      color: Colors.white)),
        backgroundColor: Color(0xFF6644C0),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                    onChanged: (value) {
                      setState(() {
                        name = value;
                      });
                    },
                    controller: TextEditingController(text: name),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Email'),
                    controller: TextEditingController(text: email),
                    enabled: false, // Disable email field
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Phone'),
                    controller: TextEditingController(text: phone),
                    enabled: false, // Disable phone field
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        password = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      showConfirmationDialog(); // Show confirmation dialog
                    },
                    child: Text('Update Profile'),
                  ),
                ],
              ),
            ),
    );
  }
}
