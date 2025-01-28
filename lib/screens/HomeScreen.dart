import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spherelink/screens/PanoramaView.dart';
import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/utils/appColors.dart';

import '../data/ViewData.dart';

class SavedView {
  final String name;
  final File thumbnail;
  final DateTime dateTime;

  SavedView(
      {required this.name, required this.thumbnail, required this.dateTime});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ViewData> savedViews = [];

  @override
  void initState() {
    super.initState();
    _loadViews();
  }

  // Mock function to simulate loading saved views
  Future<void> _loadViews() async {
    final directory = await getApplicationDocumentsDirectory();
    final viewsDir = Directory('${directory.path}/views');
    if (!await viewsDir.exists()) return;

    final files = viewsDir.listSync();
    final viewList = <ViewData>[];

    for (var file in files) {
      if (file.path.endsWith('.json')) {
        final data = jsonDecode(await File(file.path).readAsString());
        viewList.add(ViewData.fromJson(data));
      }
    }

    setState(() {
      savedViews = viewList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: savedViews.isEmpty
          ? GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PanoramicWithMarkers()),
                );
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image(
                    image: AssetImage("assets/ic_panorama.png"),
                    width: 200,
                    height: 200,
                  ),
                  Center(
                    child: Text(
                      "No views created yet! Tap to create one.",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: savedViews.length,
                itemBuilder: (context, index) {
                  final view = savedViews[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PanoramaView(view: view)));
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: view.thumbnailImage.existsSync()
                                ? Image.file(
                                    view.thumbnailImage,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Image.asset(
                                    'assets/placeholder_image.png', // Placeholder for missing thumbnails
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  view.viewName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "${view.dateTime.day}/${view.dateTime.month}/${view.dateTime.year}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
