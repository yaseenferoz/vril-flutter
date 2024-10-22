import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vril/constants.dart';

class SampleSubmissionScreen extends StatefulWidget {
  @override
  _SampleSubmissionScreenState createState() => _SampleSubmissionScreenState();
}

class _SampleSubmissionScreenState extends State<SampleSubmissionScreen> {
  String? selectedSampleId;
  String? selectedTestTypeId;

  List<Map<String, dynamic>> sampleTypes = []; // Changed to dynamic to handle any data type
  List<Map<String, dynamic>> testTypes = []; // Changed to dynamic to handle any data type

  @override
  void initState() {
    super.initState();
    fetchSampleTypes();
    fetchTestTypes();
  }

  // Fetch sample types from the API
  Future<void> fetchSampleTypes() async {
    final token = await getToken(); // Retrieve the token
    final url = '$baseUrl/api/shared/samples'; // Use $baseUrl

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token', // Pass the Bearer token
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['samples'] is List) {  // Ensure it's a list
        setState(() {
          sampleTypes = (data['samples'] as List)
              .map((sample) => {
                    'id': sample['_id'].toString(), // Ensure it's a string
                    'name': sample['type'].toString() // Ensure it's a string
                  })
              .toList();
        });
      } else {
        print('Error: Samples data is not a list');
      }
    } else {
      print('Failed to load sample types: ${response.statusCode}');
    }
  }

  // Fetch test types from the API
  Future<void> fetchTestTypes() async {
    final token = await getToken(); // Retrieve the token
    final url = '$baseUrl/api/shared/test-types'; // Use $baseUrl

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token', // Pass the Bearer token
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['testTypes'] is List) {  // Ensure it's a list
        setState(() {
          testTypes = (data['testTypes'] as List)
              .map((testType) => {
                    'id': testType['_id'].toString(), // Ensure it's a string
                    'name': testType['name'].toString() // Ensure it's a string
                  })
              .toList();
        });
      } else {
        print('Error: Test types data is not a list');
      }
    } else {
      print('Failed to load test types: ${response.statusCode}');
    }
  }

// Submit sample
Future<void> submitSample() async {
  if (selectedSampleId == null || selectedTestTypeId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select both a sample type and a test type')),
    );
    return;
  }

  final token = await getToken(); // Retrieve the token
  final url = '$baseUrl/api/customer/submit-sample'; // Use $baseUrl

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $token', // Pass the Bearer token
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'sampleId': selectedSampleId,
      'testTypeId': selectedTestTypeId,
    }),
  );

  final responseBody = jsonDecode(response.body);

  if (response.statusCode == 200 || response.statusCode == 201) {
    if (responseBody.containsKey('message') && responseBody['message'] == 'Sample submitted successfully') {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sample submitted successfully!')));

      // Reset form fields after successful submission
      setState(() {
        selectedSampleId = null;
        selectedTestTypeId = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected response from server.')));
    }
  } else {
    // Log the failed response for debugging purposes
    print('Failed to submit sample: ${response.body}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit sample.')),
    );
  }
}

  // Get token from shared preferences
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken'); // Make sure the token is stored here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sample Submission',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF6644C0),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sample Type Dropdown
            Text('Sample Type', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
              ),
              value: selectedSampleId,
              items: sampleTypes.map((sample) {
                return DropdownMenuItem<String>(
                  value: sample['id'],
                  child: Text(sample['name']!),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedSampleId = newValue;
                });
              },
              hint: Text('Select Sample Type'),
              isExpanded: true,
            ),
            SizedBox(height: 20),
            // Test Type Dropdown
            Text('Test Type', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
              ),
              value: selectedTestTypeId,
              items: testTypes.map((testType) {
                return DropdownMenuItem<String>(
                  value: testType['id'],
                  child: Text(testType['name']!),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedTestTypeId = newValue;
                });
              },
              hint: Text('Select Test Type'),
              isExpanded: true,
            ),
            SizedBox(height: 30),
            // Submit Button
            Center(
              child: ElevatedButton(
                onPressed: submitSample,
                child: Text('Submit Sample', style: TextStyle(color: Colors.white)), // Set button text color to white
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6644C0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
