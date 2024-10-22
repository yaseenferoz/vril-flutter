import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';

class SampleManagementScreen extends StatefulWidget {
  @override
  _SampleManagementScreenState createState() => _SampleManagementScreenState();
}

class _SampleManagementScreenState extends State<SampleManagementScreen> {
  int _selectedTab = 0;
  List<dynamic> samples = [];
  List<dynamic> testTypes = [];

  @override
  void initState() {
    super.initState();
    fetchSamples();
    fetchTestTypes();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Fetch samples from the API
  Future<void> fetchSamples() async {
    final token = await getToken();
    final url = '$baseUrl/api/shared/samples'; // Use baseUrl here
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        samples = jsonDecode(response.body)['samples'];
      });
    } else {
      print('Failed to load samples');
    }
  }

  // Fetch test types from the API
  Future<void> fetchTestTypes() async {
    final token = await getToken();
    final url = '$baseUrl/api/shared/test-types';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        testTypes = jsonDecode(response.body)['testTypes'];
      });
    } else {
      print('Failed to load test types');
    }
  }

  // Add new sample or test type
  Future<void> addItem(String type, String name, String description) async {
    final token = await getToken();
    final url = type == 'sample'
        ? '$baseUrl/api/vendor/create-sample'
        : '$baseUrl/api/vendor/add-test-type';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        type == 'sample' ? 'type' : 'name': name,
        'description': description,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Added 201 for success cases
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type added successfully!')),
      );

      if (type == 'sample') {
        await fetchSamples(); // Refresh sample list
      } else {
        await fetchTestTypes(); // Refresh test types list
      }
    } else {
      print('Error response: ${response.body}'); // Debugging error response
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add $type. Please try again.')),
      );
    }
  }

  // Delete sample or test type
  Future<void> deleteItem(String type, String id) async {
    final token = await getToken();
    final url = type == 'sample'
        ? '$baseUrl/api/vendor/delete-sample/$id'
        : '$baseUrl/api/vendor/delete-test-type/$id';

    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type deleted successfully!')),
      );

      if (type == 'sample') {
        await fetchSamples();
      } else {
        await fetchTestTypes();
      }

      setState(() {}); // Force UI to update
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete $type. Please try again.')),
      );
    }
  }

  // Add Item Modal
  void _showAddItemModal(String type) {
    String itemName = '';
    String itemDescription = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add $type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Name'),
                onChanged: (value) {
                  itemName = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Description'),
                onChanged: (value) {
                  itemDescription = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (itemName.isNotEmpty && itemDescription.isNotEmpty) {
                  addItem(type, itemName, itemDescription);
                  Navigator.of(context).pop(); // Close the modal after adding
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Add button handler
  void _onAddPressed() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Add Item'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showAddItemModal('sample');
              },
              child: const Text('Sample'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showAddItemModal('test type');
              },
              child: const Text('Test Type'),
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
        title: Text(
          'Sample Management',
          style: TextStyle(color: Colors.white), // Heading in white
        ),
        backgroundColor: Color(0xFF6644C0),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0
                        ? Color(0xFF6644C0)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Samples',
                    style: TextStyle(
                      color: _selectedTab == 0 ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: _onAddPressed,
                icon: Icon(Icons.add_circle, color: Color(0xFF6644C0)),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1
                        ? Color(0xFF6644C0)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Test Types',
                    style: TextStyle(
                      color: _selectedTab == 1 ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child:
                _selectedTab == 0 ? _buildSamplesList() : _buildTestTypesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplesList() {
    return ListView.builder(
      itemCount: samples.length,
      itemBuilder: (context, index) {
        final sample = samples[index];
        return ListTile(
          title: Text(sample['type']),
          subtitle: Text(sample['description']),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              deleteItem('sample', sample['_id']);
            },
          ),
        );
      },
    );
  }

  Widget _buildTestTypesList() {
    return ListView.builder(
      itemCount: testTypes.length,
      itemBuilder: (context, index) {
        final testType = testTypes[index];
        return ListTile(
          title: Text(testType['name']),
          subtitle: Text(testType['description']),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              deleteItem('test type', testType['_id']);
            },
          ),
        );
      },
    );
  }
}
