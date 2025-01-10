import 'package:flutter/material.dart';

import 'LoginScreen.dart';

class DashboardScreen extends StatelessWidget {
  final List<Map<String, String>> buildings = [
    {
      'name': 'Building 1',
      'image': 'assets/img_1.jpg',
    },
    {
      'name': 'Building 2',
      'image': 'assets/img_2.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: const Text('Dashboard'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.logout,
            size: 20,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(duration: Duration(seconds: 1),content: Text("Logout successfully!")),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select a Building to View Pipeline Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: buildings.length,
              itemBuilder: (context, index) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        5.0), // Adjust radius as needed
                  ),
                  child: ListTile(
                    leading: Image.asset(
                      buildings[index]['image']!,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                    title: Text(buildings[index]['name']!),
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => MapScreen(
                      //       buildingName: buildings[index]['name']!,
                      //     ),
                      //   ),
                      // );
                    },
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
