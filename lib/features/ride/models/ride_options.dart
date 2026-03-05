import 'package:flutter/material.dart';

class RideOption {
  final String id; // e.g. 'bike', 'auto'
  final String name;
  final String description;
  final String eta;
  final double fare;
  final IconData? icon;
  final String? imageAsset;
  final Color? iconColor; // Colored icon support
  final int seats; // Number of passenger seats

  RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.eta,
    required this.fare,
    this.icon,
    this.imageAsset,
    this.iconColor,
    required this.seats,
  });
}
