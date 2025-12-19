import 'package:flutter/material.dart';

class RideOption {
  final String name;
  final String description;
  final String eta;
  final double fare;
  final IconData icon;

  RideOption({
    required this.name,
    required this.description,
    required this.eta,
    required this.fare,
    required this.icon,
  });
}
