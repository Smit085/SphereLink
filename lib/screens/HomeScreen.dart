import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:spherelink/core/userSettings.dart';
import 'package:spherelink/screens/PanoramaView.dart';
import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/screens/PublishViewScreen.dart';
import 'package:spherelink/utils/appColors.dart';
import 'package:spherelink/widget/customSnackbar.dart';

import '../core/apiService.dart';
import '../data/ViewData.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> sortOptions = ["Name", "Date"];
  String selectedSortOption = "name";
  String currentMenu = "main";
  bool isListView = true;
  bool isLoading = true;
  bool isGroupedView = false;
  bool isAscendingName = false;
  bool isAscendingDateTime = false;
  List<ViewData> savedViews = [];
  List<ViewData> filteredViews = [];
  List<MapEntry<String, List<ViewData>>> groupedViews =
      <MapEntry<String, List<ViewData>>>[];
  TextEditingController searchController = TextEditingController();
  final UserSettings _userSettings = UserSettings();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool isLoadingPublished = true;
  List<ViewData> publishedViews = [];
  List<ViewData> filteredPublishedViews = [];
  final GlobalKey<RefreshIndicatorState> _publishedRefreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadViews();
    _loadPublishedViews();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose(); // Add this line
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublishedViews() async {
    setState(() => isLoadingPublished = true);
    try {
      final views = await ApiService().fetchPublishedViews();
      setState(() {
        publishedViews = views;
        filteredPublishedViews = List.from(views);
        isLoadingPublished = false;
      });
      print("Loaded ${views.length} published views");
    } catch (e) {
      setState(() => isLoadingPublished = false);
      print("Error loading published views: $e");
      showCustomSnackBar(context, Colors.red,
          "Failed to load published views: $e", Colors.white, "", null);
    }
  }

  void _onSearchChanged() {
    filterViews(searchController.text);
  }

  void filterViews(String query) {
    setState(() {
      final currentTab = _tabController.index;
      if (currentTab == 0) {
        // Local tab
        if (query.isEmpty) {
          filteredViews = List.from(savedViews);
        } else {
          filteredViews = savedViews
              .where((view) =>
                  view.viewName.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
      } else {
        // Published tab
        if (query.isEmpty) {
          filteredPublishedViews = List.from(publishedViews);
        } else {
          filteredPublishedViews = publishedViews
              .where((view) =>
                  view.viewName.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
      }
    });
  }

  Future<void> _loadViews() async {
    bool? savedViewType = await _userSettings.getViewType();
    setState(() {
      isListView = savedViewType ?? true;
    });
    final directory = await getApplicationDocumentsDirectory();
    final viewsDir = Directory('${directory.path}/views');
    if (!await viewsDir.exists()) {
      print("Views directory does not exist");
      await viewsDir.create(recursive: true);
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
      isLoading = false;
    });
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    if (currentMenu == 'main') {
      return [
        const PopupMenuItem(
          value: 'sort_by',
          child: SizedBox(
            width: 120,
            child: ListTile(
              title: Text('Sort by...'),
              trailing: Icon(Icons.arrow_right),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by',
          child: SizedBox(
            width: 120,
            child: ListTile(
              title: Text('Group by...'),
              trailing: Icon(Icons.arrow_right),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'display_view',
          child: SizedBox(
            width: 120,
            child: ListTile(
              title: Text(isListView ? 'Display in grid' : 'Display in list'),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: SizedBox(
            width: 120,
            child: ListTile(
              title: Text("Refresh"),
            ),
          ),
        ),
      ];
    } else if (currentMenu == 'sort_by') {
      return [
        const PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 120,
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
            width: 120,
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
            width: 120,
            child: ListTile(
              title: const Text('DateTime'),
              trailing: Icon(isAscendingDateTime
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
            width: 120,
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
            width: 120,
            child: Text('None'),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by_alphabets',
          child: SizedBox(
            width: 120,
            child: Text('A-Z'),
          ),
        ),
        const PopupMenuItem(
          value: 'group_by_name',
          child: SizedBox(
            width: 120,
            child: Text('Name'),
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
          case 'group_by_alphabets':
            groupByAlphabets();
            break;
          case 'group_by_name':
            groupByName();
            break;
          case 'display_view':
            toggleDisplayView();
          case 'refresh':
            final currentTab = _tabController.index;
            if (currentTab == 0) {
              _refreshIndicatorKey.currentState?.show();
              _loadViews();
            } else {
              _publishedRefreshKey.currentState?.show();
              _loadPublishedViews();
            }
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
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: AppColors.appprimaryColor,
                padding: const EdgeInsets.only(left: 16),
                width: double.infinity,
                child: TabBar(
                  controller: _tabController,
                  padding: const EdgeInsets.only(top: 44),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.textColorPrimary,
                  indicatorWeight: 3,
                  dividerHeight: 0,
                  labelPadding: const EdgeInsets.only(top: 4),
                  tabs: const [
                    Tab(text: "Local", height: 35),
                    Tab(text: "Published", height: 35),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        key: _refreshIndicatorKey,
                        onRefresh: _loadViews,
                        backgroundColor: Colors.white,
                        color: Colors.blue,
                        child: isLoading
                            ? isListView
                                ? ListView.builder(
                                    itemCount: 8,
                                    itemBuilder: (context, index) =>
                                        _buildShimmerTile(),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 15,
                                      childAspectRatio: 3 / 2,
                                    ),
                                    itemCount: 10,
                                    itemBuilder: (context, index) =>
                                        _buildShimmerGridTile(),
                                  )
                            : filteredViews.isEmpty
                                ? _buildEmptyState()
                                : isListView
                                    ? _buildListView()
                                    : _buildGridView(),
                      ),
                      RefreshIndicator(
                        key: _publishedRefreshKey,
                        onRefresh: _loadPublishedViews,
                        backgroundColor: Colors.white,
                        color: Colors.blue,
                        child: isLoadingPublished
                            ? isListView
                                ? ListView.builder(
                                    itemCount: 8,
                                    itemBuilder: (context, index) =>
                                        _buildShimmerTile(),
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 15,
                                      childAspectRatio: 3 / 2,
                                    ),
                                    itemCount: 10,
                                    itemBuilder: (context, index) =>
                                        _buildShimmerGridTile(),
                                  )
                            : filteredPublishedViews.isEmpty
                                ? _buildEmptyState()
                                : isListView
                                    ? _buildPublishedListView()
                                    : _buildPublishedGridView(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 16,
            right: 16,
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
                        hintText: 'Explore your views...',
                        hintStyle: const TextStyle(fontSize: 14),
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
        ],
      ),
      floatingActionButton: savedViews.isNotEmpty
          ? Container(
              width: 55,
              height: 55,
              decoration: const BoxDecoration(
                color: AppColors.appsecondaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  _tabController.index == 0
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PanoramicWithMarkers()),
                        )
                      : _tabController.index = 0;
                },
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final currentTab = _tabController.index;
    return RefreshIndicator(
      onRefresh: currentTab == 0 ? _loadViews : _loadPublishedViews,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: GestureDetector(
            onTap: () {
              if (currentTab == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PanoramicWithMarkers(),
                  ),
                );
              }
            },
            child: Center(
              child: FittedBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/ic_panorama.png",
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      textAlign: TextAlign.center,
                      currentTab == 0 && savedViews.isEmpty
                          ? "No views found! Tap to create one\nor Refresh the page."
                          : "No matching views found.",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (isLoading) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) => _buildShimmerListTile(),
      );
    }

    if (isGroupedView) {
      return ListView.builder(
        itemCount: groupedViews.length,
        itemBuilder: (context, index) {
          final group = groupedViews[index];
          final groupName = group.key;
          final groupItems = group.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupItems.length,
                itemBuilder: (context, subIndex) {
                  final view = groupItems[subIndex];
                  return _buildListTile(view);
                },
              ),
            ],
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: filteredViews.length,
        itemBuilder: (context, index) {
          final view = filteredViews[index];
          return _buildListTile(view);
        },
      );
    }
  }

  Widget _buildShimmerListTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 100,
                height: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: double.infinity, height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 150, height: 10, color: Colors.white),
                ],
              ),
            ),
            Container(width: 24, height: 24, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerTile() {
    return Shimmer.fromColors(
      baseColor: Colors.white12,
      highlightColor: Colors.white54,
      child: ListTile(
        leading: Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        title: Container(
          width: double.infinity,
          height: 10,
          color: Colors.white,
        ),
        subtitle: Container(
          width: 150,
          height: 10,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildListTile(ViewData view) {
    return ListTile(
      onTap: () {
        _showModalBottomSheet(view);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: view.thumbnailImage != null && view.thumbnailImage!.existsSync()
            ? Image.file(
                view.thumbnailImage!, // Safe to use ! after null check
                width: 100,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image);
                },
              )
            : const Icon(Icons.image),
      ),
      title: Text(
        view.viewName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${view.dateTime.day}/${view.dateTime.month}/${view.dateTime.year} "
        "${view.dateTime.hour % 12 == 0 ? 12 : view.dateTime.hour % 12}:"
        "${view.dateTime.minute.toString().padLeft(2, '0')} "
        "${view.dateTime.hour >= 12 ? 'PM' : 'AM'}",
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: !view.isPublished
          ? IconButton(
              onPressed: () async {
                view.isPublished = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublishViewScreen(view: view),
                  ),
                );
                if (view.isPublished) {
                  await _saveView(view);
                }
                setState(() {});
              },
              icon: const Icon(
                Icons.file_upload_outlined,
                color: Colors.blue,
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildShimmerGridTile() {
    return Shimmer.fromColors(
      baseColor: Colors.white12,
      highlightColor: Colors.white54,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        margin: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                  width: double.infinity, height: 10, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(width: 80, height: 10, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    if (isGroupedView) {
      return ListView.builder(
        itemCount: groupedViews.length,
        itemBuilder: (context, index) {
          final group = groupedViews[index];
          final groupName = group.key;
          final groupItems = group.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 15,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: groupItems.length,
                itemBuilder: (context, subIndex) {
                  final view = groupItems[subIndex];
                  return _buildGridTile(view);
                },
              ),
            ],
          );
        },
      );
    } else {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 15,
          childAspectRatio: 3 / 2,
        ),
        itemCount: filteredViews.length,
        itemBuilder: (context, index) {
          final view = filteredViews[index];
          return _buildGridTile(view);
        },
      );
    }
  }

  Widget _buildPublishedListView() {
    if (isGroupedView) {
      return ListView.builder(
        itemCount: groupedViews.length,
        itemBuilder: (context, index) {
          final group = groupedViews[index];
          final groupName = group.key;
          final groupItems = group.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupItems.length,
                itemBuilder: (context, subIndex) {
                  final view = groupItems[subIndex];
                  return _buildPublishedListTile(view);
                },
              ),
            ],
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: filteredPublishedViews.length,
        itemBuilder: (context, index) {
          final view = filteredPublishedViews[index];
          return _buildPublishedListTile(view);
        },
      );
    }
  }

  Widget _buildPublishedListTile(ViewData view) {
    return ListTile(
      onTap: () {
        _showModalBottomSheet(view);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: view.thumbnailImageUrl != null
            ? CachedNetworkImage(
                imageUrl: view.thumbnailImageUrl!,
                width: 100,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.image),
                memCacheWidth: 400, // Optimize GPU memory
              )
            : const Icon(Icons.image),
      ),
      title: Text(
        view.viewName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${view.dateTime.day}/${view.dateTime.month}/${view.dateTime.year} "
        "${view.dateTime.hour % 12 == 0 ? 12 : view.dateTime.hour % 12}:"
        "${view.dateTime.minute.toString().padLeft(2, '0')} "
        "${view.dateTime.hour >= 12 ? 'PM' : 'AM'}",
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      // No trailing publish button for published views since they're already published
    );
  }

  Widget _buildPublishedGridView() {
    if (isGroupedView) {
      return ListView.builder(
        itemCount: groupedViews.length,
        itemBuilder: (context, index) {
          final group = groupedViews[index];
          final groupName = group.key;
          final groupItems = group.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 15,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: groupItems.length,
                itemBuilder: (context, subIndex) {
                  final view = groupItems[subIndex];
                  return _buildPublishedGridTile(view);
                },
              ),
            ],
          );
        },
      );
    } else {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 15,
          childAspectRatio: 3 / 2,
        ),
        itemCount: filteredPublishedViews.length,
        itemBuilder: (context, index) {
          final view = filteredPublishedViews[index];
          return _buildPublishedGridTile(view);
        },
      );
    }
  }

  Widget _buildPublishedGridTile(ViewData view) {
    return GestureDetector(
      onTap: () {
        _showModalBottomSheet(view);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            view.thumbnailImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: view.thumbnailImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.image),
                    memCacheWidth: 400,
                  )
                : const Icon(Icons.videocam, color: Colors.grey),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.viewName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${view.dateTime.day}/${view.dateTime.month}/${view.dateTime.year} "
                      "\t\t${view.dateTime.hour % 12 == 0 ? 12 : view.dateTime.hour % 12}:"
                      "${view.dateTime.minute.toString().padLeft(2, '0')} "
                      "${view.dateTime.hour >= 12 ? 'PM' : 'AM'}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTile(ViewData view) {
    return GestureDetector(
      onTap: () {
        _showModalBottomSheet(view);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            view.thumbnailImage != null && view.thumbnailImage!.existsSync()
                ? Image.file(
                    view.thumbnailImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : const Icon(Icons.videocam, color: Colors.grey),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.viewName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${view.dateTime.day}/${view.dateTime.month}/${view.dateTime.year} "
                      "\t\t${view.dateTime.hour % 12 == 0 ? 12 : view.dateTime.hour % 12}:"
                      "${view.dateTime.minute.toString().padLeft(2, '0')} "
                      "${view.dateTime.hour >= 12 ? 'PM' : 'AM'}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveView(ViewData view) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final viewsDir = Directory('${directory.path}/views');
      if (!await viewsDir.exists()) {
        await viewsDir.create(recursive: true);
      }

      final jsonPath = '${viewsDir.path}/${view.viewName}.json';
      final file = File(jsonPath);

      // Ensure the file exists (optional, for safety)
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("View '${view.viewName}' not found")),
          );
        }
        return;
      }

      await file.writeAsString(jsonEncode(view.toJson()));

      if (mounted) {
        print(
            'Updated view: ${view.viewName}, isPublished: ${view.isPublished}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update view: $e")),
        );
      }
      print('Error updating view: $e');
    }
  }

  void _showModalBottomSheet(ViewData view) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Container(
          height: _tabController.index == 1 ? 170 : 270,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => {
                      Navigator.pop(context),
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PanoramaView(view: view)))
                    },
                    child: const Text("Preview",
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
                if (_tabController.index == 0)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRenameDialog(context, view);
                      },
                      child: const Text("Rename",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                if (_tabController.index == 0)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (!view.isPublished) {
                          view.isPublished = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PublishViewScreen(view: view),
                            ),
                          );
                          if (view.isPublished) {
                            await _saveView(view); // Save the updated view
                          }
                          setState(() {});
                        } else {
                          showCustomSnackBar(
                              context,
                              Colors.red,
                              "View already published!",
                              Colors.white,
                              "",
                              () => {});
                        }
                      },
                      child: const Text("Publish",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmationDialog(context, view);
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
                const Divider(
                  thickness: 7,
                  color: Colors.black12,
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Close",
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void sortByName() {
    setState(() {
      final currentTab = _tabController.index;
      final viewsToSort =
          currentTab == 0 ? filteredViews : filteredPublishedViews;
      viewsToSort.sort((a, b) {
        return isAscendingName
            ? a.viewName.compareTo(b.viewName)
            : b.viewName.compareTo(a.viewName);
      });
      isAscendingName = !isAscendingName;
    });
  }

  void sortByDateTime() {
    setState(() {
      final currentTab = _tabController.index;
      final viewsToSort =
          currentTab == 0 ? filteredViews : filteredPublishedViews;
      viewsToSort.sort((a, b) {
        return isAscendingDateTime
            ? a.dateTime.compareTo(b.dateTime)
            : b.dateTime.compareTo(a.dateTime);
      });
      isAscendingDateTime = !isAscendingDateTime;
    });
  }

  void groupByNone() {
    setState(() {
      isGroupedView = false;
      final currentTab = _tabController.index;
      if (currentTab == 0) {
        filteredViews = List.from(savedViews);
      } else {
        filteredPublishedViews = List.from(publishedViews);
      }
    });
  }

  void groupByAlphabets() {
    setState(() {
      isGroupedView = true;
      final currentTab = _tabController.index;
      final views = currentTab == 0 ? savedViews : publishedViews;
      final Map<String, List<ViewData>> group = {};
      for (var view in views) {
        final firstLetter = view.viewName[0].toUpperCase();
        if (group.containsKey(firstLetter)) {
          group[firstLetter]!.add(view);
        } else {
          group[firstLetter] = [view];
        }
      }
      final sortedGroupKeys = group.keys.toList()..sort();
      for (var key in sortedGroupKeys) {
        group[key]!.sort((a, b) => a.viewName.compareTo(b.viewName));
      }
      groupedViews =
          sortedGroupKeys.map((key) => MapEntry(key, group[key]!)).toList();
      print(groupedViews);
    });
  }

  void groupByName() {
    setState(() {
      isGroupedView = true;
      final currentTab = _tabController.index;
      final views = currentTab == 0 ? savedViews : publishedViews;
      final Map<String, List<ViewData>> group = {};
      for (var view in views) {
        final words = view.viewName.split(RegExp(r'\s+'));
        String groupKey = words.first;
        groupKey = groupKey.replaceAll(RegExp(r'\d+$'), '').trim();
        if (group.containsKey(groupKey)) {
          group[groupKey]!.add(view);
        } else {
          group[groupKey] = [view];
        }
      }
      final sortedGroupKeys = group.keys.toList()..sort();
      for (var key in sortedGroupKeys) {
        group[key]!.sort((a, b) => a.viewName.compareTo(b.viewName));
      }
      groupedViews =
          sortedGroupKeys.map((key) => MapEntry(key, group[key]!)).toList();
      print(groupedViews);
    });
  }

  void toggleDisplayView() async {
    setState(() {
      isListView = !isListView;
    });
    _userSettings.saveViewType(isListView);
  }

  Future<void> _deleteView(ViewData view) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/views/${view.viewName}.json';
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      setState(() {
        savedViews.remove(view);
        filteredViews.remove(view);
      });
      showCustomSnackBar(context, Colors.green, "View deleted successfully",
          Colors.white, "", null);
    }
  }

  Future<void> _renameView(ViewData view, String newName) async {
    final directory = await getApplicationDocumentsDirectory();
    final oldFile = File('${directory.path}/views/${view.viewName}.json');
    final newFile = File('${directory.path}/views/$newName.json');
    if (await oldFile.exists() && !await newFile.exists()) {
      await oldFile.rename(newFile.path);
      view.viewName = newName;
      await newFile.writeAsString(jsonEncode(view.toJson()));
      setState(() {
        filteredViews = List.from(savedViews);
      });
    } else {
      showCustomSnackBar(context, Colors.redAccent, "Named already exists.",
          Colors.white, "", () => {});
    }
  }

  void _showRenameDialog(BuildContext context, ViewData view) {
    TextEditingController renameController =
        TextEditingController(text: view.viewName);
    bool isNameChanged = false;

    renameController.addListener(() {
      setState(() {
        isNameChanged = renameController.text.isNotEmpty &&
            renameController.text != view.viewName;
      });
    });

    renameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: renameController.text.length,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              actionsPadding: const EdgeInsets.all(8),
              backgroundColor: AppColors.appsecondaryColor,
              title: const Text(
                "Rename",
                style: TextStyle(color: Colors.white),
              ),
              content: Theme(
                data: ThemeData(
                  textSelectionTheme: const TextSelectionThemeData(
                      selectionColor: Colors.lightBlueAccent),
                ),
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: (text) => setState(() {
                      isNameChanged = text.isNotEmpty && text != view.viewName;
                    }),
                    controller: renameController,
                    autofocus: true,
                    maxLines: 1,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.lightBlueAccent, width: 2),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.lightBlueAccent,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: isNameChanged
                      ? () {
                          _renameView(view, renameController.text);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(
                    "OK",
                    style: TextStyle(
                        color: isNameChanged
                            ? Colors.lightBlueAccent
                            : Colors.blueGrey,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, ViewData view) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          backgroundColor: AppColors.appsecondaryColor,
          title: const Text(
            "Confirm Delete",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Are you sure you want to delete this view?",
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "Cancel",
                style: TextStyle(
                    color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: () {
                _deleteView(view);
                Navigator.of(context).pop();
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
