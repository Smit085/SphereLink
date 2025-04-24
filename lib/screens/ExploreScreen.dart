import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:spherelink/screens/ViewDescriptionScreen.dart';
import '../core/apiService.dart';
import '../data/ViewData.dart';
import '../utils/appColors.dart';
import '../widget/AnimatedChoiceChip.dart';
import '../widget/customSnackbar.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:ui';

// Configure cache manager for CachedNetworkImage
final customCacheManager = CacheManager(
  Config(
    'customCacheKey',
    maxNrOfCacheObjects: 200,
    stalePeriod: const Duration(days: 7),
  ),
);

// Utility to darken a color
extension ColorExtension on Color {
  Color darken([double amount = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all';
  String? _query;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalPages = 1;
  int _totalElements = 0;
  List<ViewData> _views = [];
  bool _isLoading = false;
  bool _hasError = false;
  double? _latitude;
  double? _longitude;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  String? _lastCacheKey;
  DateTime? _lastRetry;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {});
    _scrollController.addListener(_onScroll);
    _fetchViews(_currentPage);
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showCustomSnackBar(
          context,
          Colors.red,
          "Location services are disabled",
          Colors.white,
          "Retry",
          () => _getCurrentLocation(),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showCustomSnackBar(
            context,
            Colors.red,
            "Location permissions denied",
            Colors.white,
            "Retry",
            () => _getCurrentLocation(),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        showCustomSnackBar(
          context,
          Colors.red,
          "Location permissions permanently denied",
          Colors.white,
          "Retry",
          () => _getCurrentLocation(),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (_filter == 'nearby') {
        _fetchViews(_currentPage, isRefresh: true);
      }
    } catch (e) {
      showCustomSnackBar(
        context,
        Colors.red,
        _filter == 'nearby'
            ? "Failed to get location for Nearby filter. Showing all views."
            : "Failed to get location.",
        Colors.white,
        "Retry",
        () => _getCurrentLocation(),
      );
      if (_filter == 'nearby') {
        setState(() {
          _filter = 'all';
        });
        _fetchViews(_currentPage, isRefresh: true);
      }
    }
  }

  Future<void> _fetchViews(int pageKey, {bool isRefresh = false}) async {
    if (_isLoading || (pageKey > _totalPages && !isRefresh)) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        if (isRefresh || pageKey == 1) {
          _views.clear();
        }
      });

      final result = await _apiService.fetchPublicViews(
        page: pageKey,
        pageSize: _pageSize,
        query: _query,
        filter: _filter,
        latitude: _filter == 'nearby' ? _latitude : null,
        longitude: _filter == 'nearby' ? _longitude : null,
      );
      final newViews =
          (result['views'] as List<dynamic>?)?.cast<ViewData>() ?? [];

      double? previousOffset =
          _scrollController.hasClients ? _scrollController.offset : null;

      setState(() {
        _views.addAll(newViews);
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
        _totalElements = (result['totalElements'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });

      // Restore scroll position after rebuild
      if (previousOffset != null && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(previousOffset!);
          }
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      final now = DateTime.now();
      if (_lastRetry == null || now.difference(_lastRetry!).inSeconds > 5) {
        _lastRetry = now;
        String message = "Error fetching views";
        if (e is DioError) {
          if (e.response?.statusCode == 401) {
            message = "Please log in again";
          } else if (e.response?.statusCode == 500) {
            message = "Server error, try again later";
          } else {
            message = "Network error, please check your connection";
          }
        }
        showCustomSnackBar(
          context,
          Colors.red,
          message,
          Colors.white,
          "Retry",
          () => _fetchViews(pageKey),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _currentPage = 1;
    });
    await _fetchViews(_currentPage, isRefresh: true);
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _query = _searchController.text.isEmpty ? null : _searchController.text;
        _currentPage = 1;
      });
      _fetchViews(_currentPage, isRefresh: true);
    });
  }

  void _onFilterChange(String filter) {
    setState(() {
      _filter = filter;
      _currentPage = 1;
    });
    _fetchViews(_currentPage, isRefresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _currentPage < _totalPages) {
      _currentPage++;
      _fetchViews(_currentPage);
    }
  }

  String formatViewCount(int? count) {
    if (count == null) return '0 views';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K views';
    }
    return '$count views';
  }

  String formatDateTime(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} years ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inMinutes} minutes ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget buildStarRating(double? rating) {
    const double maxRating = 5.0;
    final ratingValue = rating?.clamp(0.0, maxRating) ?? 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${ratingValue.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 14,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appsecondaryColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: Colors.white,
          color: Colors.blue,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.appprimaryColor,
                pinned: false,
                floating: true,
                snap: true,
                expandedHeight: 100.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Column(
                      children: [
                        Row(
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
                                child: ValueListenableBuilder(
                                  valueListenable: _searchController,
                                  builder: (context, value, child) {
                                    return TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Explore public views...',
                                        hintStyle:
                                            const TextStyle(fontSize: 14),
                                        prefixIcon: const Icon(Icons.search),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 10),
                                        suffixIcon:
                                            _searchController.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      color: Colors.grey,
                                                    ),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      _onSearch();
                                                    },
                                                  )
                                                : null,
                                      ),
                                      onSubmitted: (_) => _onSearch(),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: AnimatedChoiceChip(
                                  label: 'All',
                                  isSelected: _filter == 'all',
                                  onSelected: () => _onFilterChange('all'),
                                ),
                              ),
                              Expanded(
                                child: AnimatedChoiceChip(
                                  label: 'Recent',
                                  isSelected: _filter == 'recent',
                                  onSelected: () => _onFilterChange('recent'),
                                ),
                              ),
                              Expanded(
                                child: AnimatedChoiceChip(
                                  label: 'Popular',
                                  isSelected: _filter == 'most_rated',
                                  onSelected: () =>
                                      _onFilterChange('most_rated'),
                                ),
                              ),
                              Expanded(
                                child: AnimatedChoiceChip(
                                  label: 'Nearby',
                                  isSelected: _filter == 'nearby',
                                  onSelected: () => _onFilterChange('nearby'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (_isLoading && _views.isEmpty) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height -
                            kToolbarHeight -
                            MediaQuery.of(context).padding.top -
                            100.0,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 25,
                                height: 25,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (_views.isEmpty && !_isLoading && _hasError) {
                      return Container(
                        height: MediaQuery.of(context).size.height -
                            kToolbarHeight -
                            MediaQuery.of(context).padding.top -
                            100.0,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error,
                                  color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Failed to load views',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _fetchViews(_currentPage),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (_views.isEmpty && !_isLoading) {
                      return Container(
                        height: MediaQuery.of(context).size.height -
                            kToolbarHeight -
                            MediaQuery.of(context).padding.top -
                            100.0,
                        child: const Center(
                          child: Text(
                            'No views available',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      );
                    }
                    if (index == _views.length && _isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }
                    if (index == _views.length &&
                        !_isLoading &&
                        _currentPage >= _totalPages &&
                        _views.length >= _totalElements) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No more views to load',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      );
                    }
                    if (index < _views.length) {
                      final view = _views[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewDescriptionScreen(view: view),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    color: Colors.black87,
                                    width: double.infinity,
                                    height: 200,
                                    child: view.thumbnailImageUrl != null &&
                                            view.thumbnailImageUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: view.thumbnailImageUrl!,
                                            cacheManager: customCacheManager,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 15,
                                                  height: 15,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.error,
                                                    size: 50,
                                                    color: Colors.white),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image,
                                                size: 50, color: Colors.grey),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.textColorPrimary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child:
                                          buildStarRating(view.averageRating),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, right: 8, top: 8, bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipOval(
                                      child: view.creatorProfileImagePath !=
                                                  null &&
                                              view.creatorProfileImagePath!
                                                  .isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  view.creatorProfileImagePath!,
                                              cacheManager: customCacheManager,
                                              width: 35,
                                              height: 35,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 15,
                                                    height: 15,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget:
                                                  (context, url, error) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.error,
                                                      size: 20,
                                                      color: Colors.white),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.person,
                                                  size: 20),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            view.viewName ?? 'Untitled',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${view.cityName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                view.creatorName ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              Text(
                                                '• ${formatViewCount(1000)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              Text(
                                                '• ${view.dateTime != null ? formatDateTime(view.dateTime) : 'Unknown'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  childCount: _isLoading && _views.isEmpty
                      ? 1
                      : _views.isEmpty && !_isLoading
                          ? 1
                          : _views.length +
                              (_isLoading || _currentPage >= _totalPages
                                  ? 1
                                  : 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
