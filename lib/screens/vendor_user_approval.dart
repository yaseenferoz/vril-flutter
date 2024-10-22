import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // Import the constants file

class VendorUserApprovalScreen extends StatefulWidget {
  @override
  _VendorUserApprovalScreenState createState() =>
      _VendorUserApprovalScreenState();
}

class _VendorUserApprovalScreenState extends State<VendorUserApprovalScreen> {
  List<dynamic> usersAwaitingApproval = [];
  List<dynamic> filteredUsers = [];
  String? token;
  String selectedRole = 'All'; // For toggle
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadToken(); // Load token from shared preferences before making API calls
  }

  // Load token from SharedPreferences
  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('authToken');
    if (token != null) {
      fetchUsersAwaitingApproval();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please login again.')),
      );
    }
  }

  // Fetch users awaiting approval
  Future<void> fetchUsersAwaitingApproval() async {
    final url =
        '$baseUrl/api/vendor/users-awaiting-approval'; // Use baseUrl here
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token', // Use the loaded token
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        usersAwaitingApproval = jsonDecode(response.body)['users'];
        filteredUsers = usersAwaitingApproval; // Initially all users are shown
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load users')),
      );
    }
  }

  // Approve or Decline user
  Future<void> approveOrDeclineUser(String userId, bool approve) async {
    final url = '$baseUrl/api/vendor/approve-user'; // Use baseUrl here
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the loaded token
      },
      body: jsonEncode({
        'userId': userId,
        'approve': approve,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'User approved' : 'User declined')),
      );
      fetchUsersAwaitingApproval(); // Refresh the list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to ${approve ? 'approve' : 'decline'} user')),
      );
    }
  }

  // Filtering users by role and search
  void filterByRole(String role) {
    setState(() {
      selectedRole = role;
      if (role == 'All') {
        filteredUsers = usersAwaitingApproval.where((user) {
          return user['name']
              .toLowerCase()
              .contains(searchController.text.toLowerCase());
        }).toList();
      } else {
        filteredUsers = usersAwaitingApproval.where((user) {
          return user['role'] == role &&
              user['name']
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase());
        }).toList();
      }
    });
  }

  void searchUser(String query) {
    setState(() {
      filteredUsers = usersAwaitingApproval.where((user) {
        return user['name'].toLowerCase().contains(query.toLowerCase()) &&
            (selectedRole == 'All' || user['role'] == selectedRole);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
       title: Text('Approve Users', style: TextStyle(color: Colors.white)), // Ensure white text
        backgroundColor: Color(0xFF6644C0), // Bluish background color
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                border: OutlineInputBorder(),
              ),
              onChanged: searchUser, // Call search function on change
            ),
          ),
          // Toggle for filtering by role
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButtons(
                  children: const [
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text('All')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Customer')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Collector')),
                  ],
                  isSelected: [
                    selectedRole == 'All',
                    selectedRole == 'customer',
                    selectedRole == 'collector',
                  ],
                  onPressed: (index) {
                    if (index == 0) {
                      filterByRole('All');
                    } else if (index == 1) {
                      filterByRole('customer');
                    } else if (index == 2) {
                      filterByRole('collector');
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        child: ListTile(
                          title: Text(user['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Role: ${user['role']}'),
                              Text('Email: ${user['email']}'),
                              Text('Phone: ${user['phone']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    approveOrDeclineUser(user['_id'], true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(500),
                                  ),
                                  padding: const EdgeInsets.all(
                                      12), // You can adjust the padding for better appearance
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () =>
                                    approveOrDeclineUser(user['_id'], false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(500),
                                  ),
                                  padding: const EdgeInsets.all(
                                      12), // Adjust padding for a better look
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
