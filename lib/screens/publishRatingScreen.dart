import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spherelink/core/apiService.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/utils/appColors.dart';
import 'package:spherelink/widget/customSnackbar.dart';

import '../core/AppConfig.dart';

class ViewRatingScreen extends StatefulWidget {
  final String viewName;
  final String? viewId;
  final int? selectedStars;

  const ViewRatingScreen({
    super.key,
    required this.viewName,
    required this.viewId,
    this.selectedStars,
  });

  @override
  State<ViewRatingScreen> createState() => _ViewRatingScreenState();
}

class _ViewRatingScreenState extends State<ViewRatingScreen> {
  final ApiService _apiService = ApiService();
  int? _selectedStars;
  final TextEditingController _commentController = TextEditingController();
  String? userName;
  String? userProfileUrl;
  bool _isLoadingUserDetails = true;
  bool _isposting = false;

  @override
  void initState() {
    super.initState();
    _selectedStars = widget.selectedStars;
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoadingUserDetails = true;
    });
    try {
      String? firstName = await Session().getFirstName();
      String? lastName = await Session().getLastName();
      userName = "$firstName $lastName";
      userProfileUrl = await Session().getProfileImagePath();
      String baseUrl = AppConfig.apiBaseUrl;
      baseUrl = baseUrl.substring(0, baseUrl.lastIndexOf('/'));
      if (!userProfileUrl!.startsWith('http')) {
        userProfileUrl = "$baseUrl/$userProfileUrl";
      }
    } catch (e) {
      userName = "Unknown";
      userProfileUrl = null;
    }
    setState(() {
      _isLoadingUserDetails = false;
    });
  }

  Future<void> _submitRating() async {
    setState(() {
      _isposting = true;
    });
    if (_selectedStars == null || _selectedStars == 0) {
      _showRatingRequiredDialog(context);
      return;
    }

    try {
      bool success = await _apiService.addRating(
        viewId: widget.viewId!,
        stars: _selectedStars!,
        comment: _commentController.text,
      );
      if (success) {
        showCustomSnackBar(
            context, Colors.green, "Rating submitted", Colors.white, "", () {});
        _commentController.clear();
        setState(() {
          _selectedStars = null;
          _isposting = false;
        });
        Navigator.pop(context, true);
      } else {
        showCustomSnackBar(context, Colors.red, "Failed to submit rating",
            Colors.white, "", () {});
      }
    } catch (e) {
      showCustomSnackBar(
          context, Colors.red, "Error: $e", Colors.white, "", () {});
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          backgroundColor: AppColors.appsecondaryColor,
          title: const Text("Confirm", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Are you sure you want to go back without posting?",
            style: const TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("No",
                  style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text("Yes",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showRatingRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            backgroundColor: AppColors.appsecondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Please add a rating",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStars = index + 1;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          index < (_selectedStars ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appsecondaryColor,
      appBar: AppBar(
        backgroundColor: AppColors.appsecondaryColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove the back button
        title: Text(
          widget.viewName ?? 'Untitled',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        titleSpacing: 16,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.withOpacity(0.3),
              child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () => {
                        _commentController.text != "" || _selectedStars != null
                            ? _showConfirmationDialog(context)
                            : Navigator.of(context).pop()
                      }),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _isLoadingUserDetails
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: userProfileUrl != null
                                      ? NetworkImage(userProfileUrl!)
                                      : const AssetImage(
                                          'assets/default_profile.png',
                                        ) as ImageProvider,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName ?? 'Unknown',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "Posting publicly across SphereLink",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStars = index + 1;
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(
                                index < (_selectedStars ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 36,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        cursorColor: Colors.white,
                        controller: _commentController,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: "Tell others about your experience",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        maxLines: 5,
                        maxLength: 800,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: _isposting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : null,
                onPressed: _submitRating,
                label: Text(
                  _isposting ? "Posting..." : "Post",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 0),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
