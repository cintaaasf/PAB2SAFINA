class Movie{
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String rilisDate;
  final double votaverage;

  Movie({required this.id, 
  required this.title, 
  required this.overview, 
  required this.posterPath, 
  required this.backdropPath, 
  required this.rilisDate, 
  required this.votaverage});

  factory Movie.fromJson(Map<String, dynamic> json){
    return Movie(id: json['id'], 
    title: json['title'], 
    overview: json['overview'], 
    posterPath: json['poster_path'], 
    backdropPath: json['backdrop_path'], 
    rilisDate: json['release_date'], 
    votaverage: json['vote_average'].toDouble(),
    );
  }
}