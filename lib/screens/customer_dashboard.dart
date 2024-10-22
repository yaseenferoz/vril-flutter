import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';
import 'login_screen.dart'; // For Sign out
import 'sample_submission_screen.dart'; // For sample submission
import 'customer_profile_screen.dart'; // For profile page
import 'package:intl/intl.dart'; 
class CustomerDashboard extends StatefulWidget {
  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<dynamic> submittedTests = [];
  List<dynamic> submitted = [];
  List<dynamic> inProgress = [];
  List<dynamic> delivered = [];
  List<dynamic> notifications = [];
  int unreadNotificationsCount = 0;

  int _selectedTabIndex = 0; // For tab selection (Submitted, In Progress, Delivered)
  
  int currentPage = 1; // Pagination: Start with page 1
  bool isLoadingMore = false; // Whether we are currently loading more data
  bool hasMoreData = true; // Whether more data is available for loading
  final int pageSize = 5; // Number of records per page

  @override
  void initState() {
    super.initState();
    fetchSubmittedTests(); // Fetch initial set of tests
    fetchNotifications(); // Fetch unread notifications
  }

  // Fetch submitted tests with pagination
  Future<void> fetchSubmittedTests({bool loadMore = false}) async {
    if (loadMore && !hasMoreData) return; // If no more data, don't load

    setState(() {
      isLoadingMore = loadMore;
    });

    final token = await getToken(); // Retrieve the token
    final url = '$baseUrl/api/customer/submitted-tests?page=$currentPage&limit=$pageSize'; // Assume the API accepts `page` and `limit` params

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token', // Pass the Bearer token
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        if (loadMore) {
          submittedTests.addAll(data['submittedTests']); // Append new data
        } else {
          submittedTests = data['submittedTests']; // Load first page data
        }

        // Check if more data is available
        hasMoreData = data['submittedTests'].length == pageSize;
        if (hasMoreData) {
          currentPage++; // Increment page number for next request
        }

        // Filter the tests based on status
        submitted = submittedTests.where((test) => test['status'] == 'Submitted').toList();
        inProgress = submittedTests.where((test) => test['status'] != 'Submitted' && test['status'] != 'Sample Delivered').toList();
        delivered = submittedTests.where((test) => test['status'] == 'Sample Delivered').toList();

        isLoadingMore = false; // Stop the loading indicator
      });
    } else {
      print('Failed to load submitted tests: ${response.statusCode}');
      setState(() {
        isLoadingMore = false; // Stop the loading indicator
      });
    }
  }

  // Fetch unread notifications from the API
  Future<void> fetchNotifications() async {
    final token = await getToken();
    final url = '$baseUrl/api/customer/notifications'; // API URL

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        notifications = data['notifications'].where((notif) => notif['read'] == false).toList();
        unreadNotificationsCount = notifications.length;
      });
    } else {
      print('Failed to load notifications: ${response.statusCode}');
    }
  }

  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await getToken();
    final url = '$baseUrl/api/customer/notifications/$notificationId/read'; // Mark notification as read

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

  // Get token from shared preferences
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken'); // Make sure the token is stored here
  }

  // Function to get the data for the selected tab
  List<dynamic> getCurrentTabData() {
    if (_selectedTabIndex == 0) return submitted;
    if (_selectedTabIndex == 1) return inProgress;
    return delivered;
  }

  // Build tabs (Toggle switch similar to vendor dashboard)
  Widget buildTabSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildTabButton('Submitted', 0),
        buildTabButton('In Progress', 1),
        buildTabButton('Delivered', 2),
        buildRefreshButton() // Add refresh button beside "Delivered"
      ],
    );
  }

  Widget buildTabButton(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        margin: EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6644C0) : Colors.grey[300],
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Build a refresh button beside "Delivered" toggle
  Widget buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: Color(0xFF6644C0)),
      onPressed: () {
        setState(() {
          currentPage = 1;
          submittedTests.clear();
          fetchSubmittedTests(); // Refresh and reload the data
        });
      },
    );
  }

  // Load more data when scrolling
  Future<void> _loadMore() async {
    if (hasMoreData && !isLoadingMore) {
      await fetchSubmittedTests(loadMore: true);
    }
  }

  // Build notification icon with badge for unread count
  Widget buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications, color: Colors.white),
          onPressed: () {
            showNotificationsDialog();
          },
        ),
        if (unreadNotificationsCount > 0)
          Positioned(
            right: 11,
            top: 11,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$unreadNotificationsCount',
                style: TextStyle(
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

  // Show a dialog for unread notifications only
  void showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Unread Notifications'),
          content: notifications.isEmpty
              ? Text('No unread notifications available')
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
                        trailing: Icon(Icons.mark_email_read, color: Colors.green),
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
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Build list of tests with pagination
Widget buildTestList() {
  final data = getCurrentTabData();
  
  return NotificationListener<ScrollNotification>(
    onNotification: (ScrollNotification scrollInfo) {
      if (!isLoadingMore && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
        _loadMore(); // Load more when scrolled to the end
      }
      return true;
    },
    child: ListView.builder(
      itemCount: data.length + (hasMoreData ? 1 : 0), // Add 1 for loading indicator
      itemBuilder: (context, index) {
        if (index == data.length) {
          return Center(child: CircularProgressIndicator()); // Show loading indicator at the end
        }

        final test = data[index];

        // Convert the submission date into a human-readable format
        String formattedDate = 'Unknown Date';
        if (test['submissionDate'] != null) {
          DateTime submissionDate = DateTime.parse(test['submissionDate']);
          formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(submissionDate);
        }

        return Card(
          child: ListTile(
            title: Text('${test['sampleType']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test Type: ${test['testType']}'),
                Text('Status: ${test['status']}'),
                Text('Submission Date: $formattedDate'), // Display the formatted date
                Text('Description: ${test['description']}'),
              ],
            ),
          ),
        );
      },
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customer Dashboard',
          style: TextStyle(color: Colors.white), // Set text color to white
        ),
        backgroundColor: Color(0xFF6644C0),
        actions: [
          // Notification icon with badge
          buildNotificationIcon(),
          // Icon for sample submission
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SampleSubmissionScreen()),
              );
            },
          ),
          // Icon for profile section
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerProfileScreen()),
              );
            },
          ),
          // Popup menu for sign out
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String result) {
              if (result == 'Sign Out') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Remove all routes from the stack
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Sign Out',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Build the toggle switch for tabs with refresh button
            buildTabSwitch(),
            SizedBox(height: 10),
            // Display the data for the current selected tab with pagination
            Expanded(
              child: getCurrentTabData().isEmpty
                  ? Center(child: Text('No data available for this tab'))
                  : buildTestList(),
            ),
          ],
        ),
      ),
    );
  }
}
