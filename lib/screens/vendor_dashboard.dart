import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';
import 'package:vril/screens/profile_screen.dart';
import 'login_screen.dart';
import 'sample_management.dart';
import 'vendor_user_approval.dart';
import 'vendor_users_screen.dart';
import 'package:intl/intl.dart';

class VendorDashboard extends StatefulWidget {
  @override
  _VendorDashboardState createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  List<dynamic> displayedSamples = [];
  List<dynamic> inProgressSamples = [];
  List<dynamic> completedSamples = [];
  List<dynamic> notifications = [];
  bool isLoading = true;
  String searchQuery = '';
  int currentPage = 1;
  int itemsPerPage = 5;
  int _selectedTab = 0; // 0 for In Progress, 1 for Completed
  int unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    fetchSamples();
    fetchNotifications(); // Fetch unread notifications
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Fetch samples from the API
  Future<void> fetchSamples() async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/submitted-samples'; // Use baseUrl here

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Separate in-progress and completed samples
      setState(() {
        inProgressSamples = data['samples']
            .where((sample) => sample['status'] != 'Sample Delivered')
            .toList();
        completedSamples = data['samples']
            .where((sample) => sample['status'] == 'Sample Delivered')
            .toList();

        updateDisplayedSamples();
        isLoading = false;
      });
    } else {
      print('Failed to load samples: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load samples.')),
      );
    }
  }

  // Fetch unread notifications for vendor
  Future<void> fetchNotifications() async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/notifications'; // Example API for notifications

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        notifications = data['notifications']
            .where((notif) => notif['read'] == false)
            .toList();
        unreadNotificationsCount = notifications.length; // Count unread notifications
      });
    } else {
      print('Failed to load notifications: ${response.statusCode}');
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/notifications/$notificationId/read';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      fetchNotifications(); // Refresh notifications after marking as read
    } else {
      print('Failed to mark notification as read: ${response.statusCode}');
    }
  }

  // Update sample status via the API
  Future<void> updateSampleStatus(
      String sampleRequestId, String newStatus) async {
    final token = await getToken();
    final url = '$baseUrl/api/vendor/update-sample-status'; // Use baseUrl here

    print(
        'Updating status for sampleRequestId: $sampleRequestId with status: $newStatus');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sampleRequestId': sampleRequestId,
        'status': newStatus,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sample status updated to $newStatus.')),
      );
      fetchSamples(); // Refresh samples after updating status
    } else {
      print('Failed to update status: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sample status.')),
      );
    }
  }

  // Update the displayed samples based on search and tab selection
  void updateDisplayedSamples() {
    List<dynamic> filteredSamples =
        _selectedTab == 0 ? inProgressSamples : completedSamples;

    // Apply search query filter
    if (searchQuery.isNotEmpty) {
      filteredSamples = filteredSamples
          .where((sample) =>
              sample['sampleType']
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              sample['customerName']
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Ensure the pagination is within the valid range
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= filteredSamples.length) {
      currentPage = 1; // Reset to the first page if out of bounds
    }

    // Avoid out-of-range issues by safely sublisting
    setState(() {
      displayedSamples = filteredSamples.isNotEmpty
          ? filteredSamples.sublist(
              startIndex,
              endIndex > filteredSamples.length
                  ? filteredSamples.length
                  : endIndex,
            )
          : []; // If no results, set an empty list
    });
  }

  // Change page for pagination
  void changePage(int newPage) {
    setState(() {
      currentPage = newPage;
      updateDisplayedSamples();
    });
  }

  // Build the sample list UI
  Widget _buildSamplesList() {
    return ListView.builder(
      itemCount: displayedSamples.length,
      itemBuilder: (context, index) {
        final sample = displayedSamples[index];

        // Handle cases where status or _id might be null
        final currentStatus = sample['status'] ?? 'Unknown Status'; // Provide default if null
        final customerName = sample['customerName'] ?? 'Unknown Customer';
        final collectorName = sample['collectorName'] ?? 'Waiting for Collector';
        final sampleRequestId = sample['_id'] ?? ''; // Ensure _id is not null

        // Skip any samples with missing _id
        if (sampleRequestId.isEmpty) {
          return ListTile(
            title: Text('Invalid Sample: Missing ID'),
          );
        }

        // Parse and format the submission date
        String formattedDate = 'Unknown Date';
        if (sample['submissionDate'] != null) {
          DateTime submissionDate = DateTime.parse(sample['submissionDate']);
          formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(submissionDate); // Format the date
        }

        // Dynamically set the next possible status based on the current status
        List<String> statusOptions = [];
        if (currentStatus == 'Submitted' || currentStatus == 'Sample Received') {
          statusOptions = ['Sample in Test'];
        } else if (currentStatus == 'Sample in Test') {
          statusOptions = ['Sample Tested'];
        } else if (currentStatus == 'Sample Tested') {
          statusOptions = ['Sample Delivered'];
        }

        // Ensure that the current status is part of the dropdown options
        if (!statusOptions.contains(currentStatus)) {
          statusOptions.add(currentStatus); // Add current status to the dropdown items
        }

        return ListTile(
          title: Text('Sample Type: ${sample['sampleType'] ?? 'Unknown Sample Type'}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: $customerName'),
              Text('Collector: $collectorName'),
              Text('Status: $currentStatus'),
              Text('Submission Date: $formattedDate'), // Display the formatted date
            ],
          ),
          trailing: currentStatus == 'Sample Delivered'
              ? Text('Delivered', style: TextStyle(color: Colors.green)) // No status change allowed
              : DropdownButton<String>(
                  value: statusOptions.contains(currentStatus) ? currentStatus : statusOptions.first,
                  underline: Container(), // Remove the default underline
                  isExpanded: false, // Ensure compact dropdown
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  dropdownColor: Colors.white,
                  elevation: 3, // Add slight elevation for dropdown
                  items: statusOptions
                      .map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null && currentStatus != 'Sample Delivered') {
                      updateSampleStatus(sampleRequestId, newStatus); // Pass _id as sampleRequestId
                    }
                  },
                ),
        );
      },
    );
  }

  // Build notification icon with badge
  Widget buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () {
            showNotificationsDialog();
          },
        ),
        if (unreadNotificationsCount > 0)
          Positioned(
            right: 11,
            top: 11,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$unreadNotificationsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // Show unread notifications in a dialog
  void showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unread Notifications'),
          content: notifications.isEmpty
              ? const Text('No unread notifications available.')
              : Container(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return ListTile(
                        title: Text(notif['message']),
                        subtitle: Text('Date: ${notif['createdAt']}'),
                        trailing: const Icon(Icons.mark_email_read, color: Colors.green),
                        onTap: () {
                          markNotificationAsRead(notif['_id']);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
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
        title: const Text('Vendor Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6644C0),
        actions: <Widget>[
          buildNotificationIcon(), // Add notification icon with badge
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white), // Profile icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VendorProfileScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String result) async {
              if (result == 'Approve Users') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VendorUserApprovalScreen()),
                );
              } else if (result == 'Users') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VendorUsersScreen()),
                );
              } else if (result == 'Sample Management') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SampleManagementScreen()),
                );
              } else if (result == 'Sign Out') {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.remove('authToken'); // This removes the token

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Approve Users',
                child: Text('Approve Users'),
              ),
              const PopupMenuItem<String>(
                value: 'Users',
                child: Text('Users'),
              ),
              const PopupMenuItem<String>(
                value: 'Sample Management',
                child: Text('Sample Management'),
              ),
              const PopupMenuItem<String>(
                value: 'Sign Out',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Sample or Customer',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) {
                      setState(() {
                        searchQuery = query;
                        currentPage = 1; // Reset to first page after search
                        updateDisplayedSamples();
                      });
                    },
                  ),
                ),
                // Tabs: In Progress and Completed with Refresh Button
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTab = 0;
                            currentPage = 1;
                            updateDisplayedSamples();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTab == 0
                              ? Colors.blue
                              : Colors.grey[300], // Changed from primary to backgroundColor
                          elevation: 5,
                          shadowColor: Colors.grey,
                        ),
                        child: Text(
                          'In Progress',
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTab = 1;
                            currentPage = 1;
                            updateDisplayedSamples();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTab == 1
                              ? Colors.blue
                              : Colors.grey[300], // Changed from primary to backgroundColor
                          elevation: 5,
                          shadowColor: Colors.grey,
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue), // Refresh button
                        onPressed: () {
                          fetchSamples(); // Refresh the samples on click
                        },
                      ),
                    ],
                  ),
                ),
                // Sample list
                Expanded(
                  child: _buildSamplesList(),
                ),
                // Pagination controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: currentPage > 1
                          ? () => changePage(currentPage - 1)
                          : null,
                    ),
                    Text('Page $currentPage'),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: displayedSamples.length == itemsPerPage
                          ? () => changePage(currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
