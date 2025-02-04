import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spherelink/screens/PanoramaView.dart';
import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/utils/appColors.dart';

import '../data/ViewData.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> sortOptions = ["Name", "Date"];
  String selectedSortOption = "name";
  String currentMenu = "main";
  bool isListView = false;
  bool isGroupedView = false;
  bool isAscendingName = false;
  bool isAscendingDuration = false;
  List<ViewData> savedViews = [];
  List<ViewData> filteredViews = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadViews();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    filterViews(searchController.text);
  }

  void filterViews(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredViews = List.from(savedViews);
      } else {
        filteredViews = savedViews
            .where((view) =>
                view.viewName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _loadViews() async {
    final directory = await getApplicationDocumentsDirectory();
    final viewsDir = Directory('${directory.path}/views');
    if (!await viewsDir.exists()) {
      print("Views directory does not exist");
      return;
    }

    final files = viewsDir.listSync();
    final viewList = <ViewData>[];

    for (var file in files) {
      if (file.path.endsWith('.json')) {
        final data = jsonDecode(await File(file.path).readAsString());
        viewList.add(ViewData.fromJson(data));
      }
    }

    print("Loaded ${viewList.length} views");
    setState(() {
      savedViews = viewList;
      filteredViews = List.from(viewList);
    });
  }

  void _sortViews(String sortBy) {
    setState(() {
      if (sortBy == 'Name') {
        filteredViews.sort((a, b) => a.viewName.compareTo(b.viewName));
      } else if (sortBy == 'Date') {
        filteredViews.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
    });
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    if (currentMenu == 'main') {
      return [
        const PopupMenuItem(
          value: 'sort_by',
          child: SizedBox(
            width: 120, // Fixed width
            child: ListTile(
              title: Text('Sort by...'),
              trailing: Icon(Icons.arrow_right),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by',
          child: SizedBox(
            width: 120, // Fixed width
            child: ListTile(
              title: Text('Group by...'),
              trailing: Icon(Icons.arrow_right),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'display_view',
          child: SizedBox(
            width: 120, // Fixed width
            child: ListTile(
              title: Text(isListView ? 'Display in grid' : 'Display in list'),
            ),
          ),
        ),
      ];
    } else if (currentMenu == 'sort_by') {
      return [
        const PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 120, // Fixed width
            child: Text(
              'Sort by...',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'sort_by_name',
          child: SizedBox(
            width: 120, // Fixed width
            child: ListTile(
              title: const Text('Name'),
              trailing: Icon(isAscendingName
                  ? Icons.arrow_drop_up
                  : Icons.arrow_drop_down),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'sort_by_date_time',
          child: SizedBox(
            width: 120, // Fixed width
            child: ListTile(
              title: const Text('Duration'),
              trailing: Icon(isAscendingDuration
                  ? Icons.arrow_drop_up
                  : Icons.arrow_drop_down),
            ),
          ),
        ),
      ];
    } else if (currentMenu == 'group_by') {
      return [
        const PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 120, // Fixed width
            child: Text(
              'Group by...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by_none',
          child: SizedBox(
            width: 120, // Fixed width
            child: Text('None'),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by_name',
          child: SizedBox(
            width: 120, // Fixed width
            child: Text('Name'),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by_folder',
          child: SizedBox(
            width: 120, // Fixed width
            child: Text('Folder'),
          ),
        ),
      ];
    }
    return [];
  }

  void _handleMenuItem(String value) {
    setState(() {
      if (value == 'sort_by' || value == 'group_by') {
        currentMenu = value;
        _showCustomMenu(context);
      } else {
        // Handle actual sorting or grouping
        switch (value) {
          case 'sort_by_name':
            sortByName();
            break;
          case 'sort_by_date_time':
            sortByDateTime();
            break;
          case 'group_by_none':
            groupByNone();
            break;
          case 'group_by_name':
            groupByName();
            break;
          case 'display_view':
            toggleDisplayView();
            break;
        }
        currentMenu = 'main';
      }
    });
  }

  void _showCustomMenu(BuildContext context) {
    const RelativeRect position = RelativeRect.fromLTRB(140, 100, 15, 0);
    showMenu<String>(
      color: Colors.white,
      context: context,
      position: position,
      items: _buildMenuItems(context),
    ).then((value) {
      if (value == null) {
        setState(() {
          currentMenu = 'main';
        });
      } else {
        _handleMenuItem(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search views',
                        hintStyle: TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.sort_rounded),
                    onPressed: () {
                      _showCustomMenu(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredViews.isEmpty
                ? GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PanoramicWithMarkers()),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Image(
                          image: AssetImage("assets/ic_panorama.png"),
                          width: 200,
                          height: 200,
                        ),
                        Center(
                          child: Text(
                            savedViews.isEmpty
                                ? "No views found! Tap to create one."
                                : "No matching views found.",
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: filteredViews.length,
                      itemBuilder: (context, index) {
                        final view = filteredViews[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        PanoramaView(view: view)));
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
                                          'assets/placeholder_image.png',
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
          ),
        ],
      ),
    );
  }

  void sortByName() {
    setState(() {
      filteredViews.sort((a, b) {
        return isAscendingName
            ? a.viewName.compareTo(b.viewName)
            : b.viewName.compareTo(a.viewName);
      });
      isAscendingName = !isAscendingName;
    });
  }

  void sortByDateTime() {
    setState(() {
      filteredViews.sort((a, b) {
        return isAscendingName
            ? a.dateTime.compareTo(b.dateTime)
            : b.dateTime.compareTo(a.dateTime);
      });
      isAscendingName = !isAscendingName;
    });
  }

  void groupByNone() {
    setState(() {
      isGroupedView = false;
      filteredViews = List.from(savedViews);
    });
  }

  void toggleDisplayView() {
    setState(() {
      isListView = !isListView;
    });
  }

  void groupByName() {}
}
