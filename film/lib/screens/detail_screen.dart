import 'package:film/models/movie.dart';
import 'package:flutter/material.dart';

class DetailScreen extends StatelessWidget {
  final Movie movie;

  const DetailScreen({super.key, required this.movie});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network('https://image.tmdb.org/t/p/w500${movie.backdropPath}',
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(movie.overview),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.blue),
              SizedBox(
                width: 10,
              ),
              Text(
                'Release Data ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(movie.rilisDate)
            ],
          ),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(
                width: 10,
              ),
              Text(
                'Rating ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(movie.votaverage.toString()),
            ],
          ),
        ],
      ),
    );
  }
}