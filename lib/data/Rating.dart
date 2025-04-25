class Rating {
  final String? userName;
  final int stars;
  final String? comment;
  final DateTime? createdAt;

  Rating({this.userName, required this.stars, this.comment, this.createdAt});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
        userName: json['userName'] as String?,
        stars: json['stars'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(
            json["createdAt"] as String? ?? DateTime.now().toIso8601String()));
  }
}
