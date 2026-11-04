import 'dart:io';
import 'package:flutter/material.dart';

Widget buildSongArtwork({
  required String? artworkPathOrUrl,
  double width = 45,
  double height = 45,
  double borderRadius = 8,
}) {
  if (artworkPathOrUrl == null || artworkPathOrUrl.isEmpty) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.music_note, color: Colors.white54, size: width * 0.5),
    );
  }

  if (artworkPathOrUrl.startsWith('http://') || artworkPathOrUrl.startsWith('https://')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        artworkPathOrUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade800,
          child: Icon(Icons.music_note, color: Colors.white54, size: width * 0.5),
        ),
      ),
    );
  } else {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(artworkPathOrUrl),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade800,
          child: Icon(Icons.music_note, color: Colors.white54, size: width * 0.5),
        ),
      ),
    );
  }
}