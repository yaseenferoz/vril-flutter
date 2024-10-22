import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';
import 'package:vril/screens/collector_profile_screen.dart';
import 'login_screen.dart'; // For Sign out
import 'package:intl/intl.dart';
class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  _CollectorDashboardState createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  List<dynamic> samplesToCollect = [];
  List<dynamic> samplesDelivered = [];
  List<dynamic> samplesCollected = [];
  List<dynamic> notifications = [];
  int unreadNotificationsCount = 0;
  int _selectedTabIndex = 0; // 0 for "Submitted by Customer", 1 for "Collected", 2 for "Submitted to Vendor"
  bool isLoading = false; // For loading indicator

  @override
  void initState() {
    super.initState();
    fetchSamples(); // Fetch initial samples
    fetchNotifications(); // Fetch unread notifications
  }

  // Fetch samples for all tabs
  Future<void> fetchSamples() async {
    setState(() {
      isLoading = true;
    });

    final token = await getToken();
    final urlSamplesToCollect = '$baseUrl/api/collector/samples-to-collect';
    final urlSamplesCollected = '$baseUrl/api/collector/samples-collected';
    final urlSamplesDelivered = '$baseUrl/api/collector/samples-delivered';

    try {
      final responseSamplesToCollect = await http.get(
        Uri.parse(urlSamplesToCollect),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final responseSamplesCollected = await http.get(
        Uri.parse(urlSamplesCollected),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final responseSamplesDelivered = await http.get(
        Uri.parse(urlSamplesDelivered),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (responseSamplesToCollect.statusCode == 200 &&
          responseSamplesCollected.statusCode == 200 &&
          responseSamplesDelivered.statusCode == 200) {
        setState(() {
          samplesToCollect = jsonDecode(responseSamplesToCollect.body)['samplesToCollect'];
          samplesCollected = jsonDecode(responseSamplesCollected.body)['samplesCollected'];
          samplesDelivered = jsonDecode(responseSamplesDelivered.body)['samplesDelivered'];
        });
      } else {
        print('Error in fetching data: ${responseSamplesToCollect.statusCode} / ${responseSamplesDelivered.statusCode}');
      }
    } catch (e) {
      print('Exception caught: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch unread notifications from the API
  Future<void> fetchNotifications() async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/notifications'; // Use the correct API endpoint

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
        unreadNotificationsCount = notifications.length;
      });
    } else {
      print('Failed to load notifications: ${response.statusCode}');
    }
  }
// Function to format date
String formatDate(String dateStr) {
  try {
    final DateTime parsedDate = DateTime.parse(dateStr);
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss'); // Customize the format as needed
    return formatter.format(parsedDate);
  } catch (e) {
    return dateStr; // Return the original string if parsing fails
  }
}

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/notifications/$notificationId/read';

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

  // Update sample status to "Collected"
  Future<void> collectSample(String sampleRequestId) async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/collect-sample';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sampleRequestId': sampleRequestId,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample marked as Collected!')),
      );
      fetchSamples(); // Refresh after updating
    } else {
      print('Failed to update sample status');
    }
  }

  // Update sample status to "Delivered to Vendor"
  Future<void> deliverSample(String sampleRequestId) async {
    final token = await getToken();
    final url = '$baseUrl/api/collector/deliver-sample'; // Deliver to vendor

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sampleRequestId': sampleRequestId,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample delivered to Vendor!')),
      );
      fetchSamples(); // Refresh after updating
    } else {
      print('Failed to update sample status');
    }
  }

  // Get token from shared preferences
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
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
                        trailing:
                            const Icon(Icons.mark_email_read, color: Colors.green),
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

  // Build notification icon with badge
  Widget buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: showNotificationsDialog,
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

  // Build tabs (Toggle switch similar to customer dashboard)
  Widget buildTabSwitch() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0), // Added more padding at the top
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: buildTabButton('Submitted', 0)),
          Flexible(child: buildTabButton('Collected', 1)),
          Flexible(child: buildTabButton('Delivered', 2)),
        ],
      ),
    );
  }

  // Build tab buttons
  Widget buildTabButton(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6644C0) : Colors.grey[300],
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Build refresh button
  Widget buildRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white),
      onPressed: fetchSamples,
    );
  }

  // Build profile button
  Widget buildProfileButton() {
    return IconButton(
      icon: const Icon(Icons.person, color: Colors.white),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CollectorProfileScreen()), // Navigate to Collector Profile Screen
        );
      },
    );
  }

  // Get the data for the selected tab
  List<dynamic> getCurrentTabData() {
    if (_selectedTabIndex == 0) return samplesToCollect;
    if (_selectedTabIndex == 1) return samplesCollected;
    return samplesDelivered;
  }

  // Build the sample list
Widget buildSampleList() {
  final data = getCurrentTabData();
  if (data.isEmpty) {
    return const Center(child: Text('No data available for this tab', style: TextStyle(color: Colors.white)));
  }

  return ListView.builder(
    itemCount: data.length,
    itemBuilder: (context, index) {
      final sample = data[index];

      return Card(
        child: ListTile(
          title: Text(sample['sampleType'], style: const TextStyle(color: Colors.black)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${sample['customerName']}', style: const TextStyle(color: Colors.black)),
              Text('Status: ${sample['status']}', style: const TextStyle(color: Colors.black)),
              Text('Submission Date: ${formatDate(sample['submissionDate'])}', style: const TextStyle(color: Colors.black)), // Use formatDate here
              Text('Description: ${sample['description']}', style: const TextStyle(color: Colors.black)),
            ],
          ),
          trailing: _selectedTabIndex == 0
              ? ElevatedButton(
                  onPressed: () => collectSample(sample['sampleRequestId']),
                  child: const Text('Collected', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6644C0)),
                )
              : _selectedTabIndex == 1
                  ? ElevatedButton(
                      onPressed: () => deliverSample(sample['sampleRequestId']),
                      child: const Text('Deliver', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6644C0)),
                    )
                  : ElevatedButton(
                      onPressed: null,
                      child: const Text('Delivered', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6644C0).withOpacity(0.5)),
                    ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collector Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6644C0),
        actions: [
          buildNotificationIcon(),
          buildProfileButton(),
          buildRefreshButton(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String result) {
              if (result == 'Sign Out') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                buildTabSwitch(),
                const SizedBox(height: 10),
                Expanded(child: buildSampleList()),
              ],
            ),
    );
  }
}
