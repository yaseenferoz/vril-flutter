import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // Import your constants for baseUrl

class VendorUsersScreen extends StatefulWidget {
  @override
  _VendorUsersScreenState createState() => _VendorUsersScreenState();
}

class _VendorUsersScreenState extends State<VendorUsersScreen> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = []; // Store filtered users
  bool isLoading = true;
  String searchQuery = ''; // Store search query
  String selectedRole = 'All'; // For toggle feature
  int currentPage = 1; // Current page for pagination
  int totalPages = 1; // Total pages from the API
  int itemsPerPage = 5; // Number of users per page

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // Fetch users from the API with pagination and search query
  Future<void> fetchUsers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    // Adjust the URL to exclude vendors and superAdmins when the selectedRole is 'All'
    final roleParam = selectedRole == 'All' ? '' : selectedRole;
    final url = '$baseUrl/api/vendor/users?page=$currentPage&limit=$itemsPerPage&search=$searchQuery&role=$roleParam';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> userList = data['users'];

      setState(() {
        users = userList;
        filteredUsers = userList; // Initially, filtered users are the same as fetched users
        totalPages = data['totalPages'];
        isLoading = false;
      });
    } else {
      print('Failed to load users. Status Code: ${response.statusCode}');
      print('Response: ${response.body}');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Perform search when search icon is clicked
  void searchUsers() {
    setState(() {
      searchQuery = searchController.text;
      currentPage = 1; // Reset to page 1 when searching
      fetchUsers(); // Fetch users with the search query
    });
  }

  // Toggle filter by role
  void toggleRole(String role) {
    setState(() {
      selectedRole = role;
      currentPage = 1; // Reset to page 1 when filtering by role
      fetchUsers(); // Fetch users with the selected role
    });
  }

  // Handle pagination: Get the users for the next page
  void nextPage() {
    if (currentPage < totalPages) {
      setState(() {
        currentPage++;
        fetchUsers(); // Fetch next page of users
      });
    }
  }

  // Handle pagination: Get the users for the previous page
  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
        fetchUsers(); // Fetch previous page of users
      });
    }
  }

  // Delete user with confirmation dialog
  Future<void> deleteUser(String userId) async {
    final confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete User'),
          content: Text('Are you sure you want to delete this user?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss the dialog
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop(true); // Proceed to delete the user
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final url = '$baseUrl/api/vendor/delete-user/$userId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          users.removeWhere((user) => user['_id'] == userId);
          fetchUsers(); // Re-fetch users after deletion
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF6644C0),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by name, email, or phone',
                border: OutlineInputBorder(),
                // Remove the prefix icon to have only one search icon
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchUsers, // Trigger search when clicking the icon
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: Text('All'),
                  selected: selectedRole == 'All',
                  onSelected: (_) => toggleRole('All'),
                ),
                ChoiceChip(
                  label: Text('Customer'),
                  selected: selectedRole == 'customer',
                  onSelected: (_) => toggleRole('customer'),
                ),
                ChoiceChip(
                  label: Text('Collector'),
                  selected: selectedRole == 'collector',
                  onSelected: (_) => toggleRole('collector'),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(child: Text('No users found'))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                                  child: ListTile(
                                    title: Text(user['name']),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Email: ${user['email']}'),
                                        Text('Phone: ${user['phone']}'),
                                        Text('Role: ${user['role']}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        deleteUser(user['_id']);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: previousPage,
                                child: Text('Previous'),
                              ),
                              Text('Page $currentPage of $totalPages'),
                              TextButton(
                                onPressed: nextPage,
                                child: Text('Next'),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
