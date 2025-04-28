import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spherelink/core/apiService.dart';
import 'package:spherelink/data/Rating.dart';
import 'package:spherelink/data/ViewData.dart';
import 'package:spherelink/screens/ViewMapScreen.dart';
import 'package:spherelink/screens/publishRatingScreen.dart';
import 'package:spherelink/utils/appColors.dart';
import 'package:spherelink/widget/customSnackbar.dart';
import 'PanoramaView.dart';
import 'dart:ui';

class ViewDescriptionScreen extends StatefulWidget {
  final ViewData view;
  const ViewDescriptionScreen({super.key, required this.view});

  @override
  State<ViewDescriptionScreen> createState() => _ViewDescriptionScreenState();
}

class _ViewDescriptionScreenState extends State<ViewDescriptionScreen> {
  final ApiService _apiService = ApiService();
  List<Rating> _ratings = [];
  bool _isLoadingRatings = true;
  int _ratingPage = 1;
  final int _ratingPageSize = 5;
  int _totalRatings = 0;
  int? _selectedStars;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings(
      {bool refresh = false, bool isLoadMore = false}) async {
    try {
      setState(() {
        if (refresh) {
          _ratings.clear();
          _ratingPage = 1;
          _isLoadingRatings = true;
        } else if (isLoadMore) {
          _isLoadingMore = true;
        } else {
          _isLoadingRatings = true;
        }
      });
      final response = await _apiService.fetchRatings(
        viewId: widget.view.viewId!,
        page: _ratingPage,
        pageSize: _ratingPageSize,
      );
      setState(() {
        _ratings.addAll(response['ratings']);
        _totalRatings = response['totalElements'] ?? 0;
        _ratingPage++;
        _isLoadingRatings = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      showCustomSnackBar(context, Colors.red, "Failed to load ratings",
          Colors.white, "", () {});
      setState(() {
        if (isLoadMore) {
          _isLoadingMore = false;
        } else {
          _isLoadingRatings = false;
        }
      });
    }
  }

  void _shareView() {
    final shareUrl = "http://192.168.126.30:8080/views/${widget.view.viewId}";
    Share.share('Check out this view: $shareUrl',
        subject: widget.view.viewName);
  }

  Widget _buildStarRating(double? rating) {
    final ratingValue = rating?.clamp(0.0, 5.0) ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ratingValue.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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

  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      extendBodyBehindAppBar: true,
      floatingActionButton: Container(
        width: 55,
        height: 55,
        decoration: const BoxDecoration(
          color: AppColors.textColorPrimary,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.map_rounded, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewMapScreen(view: widget.view),
              ),
            );
          },
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _shareView,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.view.thumbnailImageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) =>
                        Image.asset('assets/image_load_failed.png'),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overflow: TextOverflow.ellipsis,
                          widget.view.viewName ?? 'Untitled',
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              const Shadow(
                                color: Colors.black45,
                                offset: Offset(1, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          overflow: TextOverflow.ellipsis,
                          widget.view.cityName ?? 'Unknown City',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Row(
                          children: [
                            _buildStarRating(widget.view.averageRating),
                            const SizedBox(width: 4),
                            Text(
                              "($_totalRatings)",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: widget.view.creatorProfileImagePath !=
                                null
                            ? NetworkImage(widget.view.creatorProfileImagePath!)
                            : const AssetImage(
                                'assets/default_profile.png',
                              ) as ImageProvider,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        overflow: TextOverflow.ellipsis,
                        widget.view.creatorName ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.view.description!,
                    style: GoogleFonts.poppins(),
                  ),
                  const Divider(
                    thickness: 1,
                    color: AppColors.appsecondaryColor,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reviews',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ViewRatingScreen(
                                    viewName: widget.view.viewName,
                                    viewId: widget.view.viewId)),
                          ).then((result) {
                            if (result == true) {
                              _fetchRatings(refresh: true);
                            }
                          });
                        },
                        child: Text('Add review',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            )),
                      ),
                    ],
                  ),
                  _isLoadingRatings && _ratings.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : _ratings.isEmpty
                          ? Center(
                              child: Column(
                                children: [
                                  Text(
                                    'No ratings yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                ViewRatingScreen(
                                                    viewName:
                                                        widget.view.viewName,
                                                    viewId:
                                                        widget.view.viewId)),
                                      ).then((result) {
                                        if (result == true) {
                                          _fetchRatings(refresh: true);
                                        }
                                      });
                                    },
                                    child: Text(
                                      'Be the first to review!',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _ratings.length,
                                  itemBuilder: (context, index) {
                                    final rating = _ratings[index];
                                    return ListTile(
                                      isThreeLine: true,
                                      leading: const CircleAvatar(
                                        radius: 20,
                                        backgroundImage: AssetImage(
                                            'assets/default_profile.png'),
                                      ),
                                      title: Text(
                                        overflow: TextOverflow.ellipsis,
                                        rating.userName ?? 'Anonymous',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children:
                                                    List.generate(5, (index) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6.0),
                                                    child: Icon(
                                                      index < rating.stars
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      color: Colors.amber,
                                                      size: 20,
                                                    ),
                                                  );
                                                }),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .textColorPrimary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  formatDateTime(
                                                      rating.createdAt),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (rating.comment != null)
                                            Text(
                                              rating.comment!,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (_ratings.length < _totalRatings)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: GestureDetector(
                                      onTap: _isLoadingMore
                                          ? null
                                          : () =>
                                              _fetchRatings(isLoadMore: true),
                                      child: _isLoadingMore
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.teal,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: Colors.teal),
                                                Text(
                                                  'View More',
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Colors.teal),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                  const Divider(
                    thickness: 1,
                    color: AppColors.appsecondaryColor,
                  ),
                  Text(
                    'Rate and review',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.view.creatorProfileImagePath !=
                                null
                            ? NetworkImage(widget.view.creatorProfileImagePath!)
                            : const AssetImage(
                                'assets/default_profile.png',
                              ) as ImageProvider,
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStars = index + 1;
                              });
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ViewRatingScreen(
                                        viewName: widget.view.viewName,
                                        viewId: widget.view.viewId,
                                        selectedStars: _selectedStars)),
                              ).then((result) {
                                if (result == true) {
                                  _fetchRatings(refresh: true);
                                  setState(() {
                                    _selectedStars = 0;
                                  });
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: 20),
                              curve: Curves.easeInOut,
                              child: Icon(
                                index < (_selectedStars ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 40,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                    thickness: 1,
                    color: AppColors.appsecondaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
