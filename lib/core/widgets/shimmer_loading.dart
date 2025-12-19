import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonRideCard extends StatelessWidget {
  const SkeletonRideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 100, height: 14, color: Colors.white),
                Container(width: 50, height: 14, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 24, height: 24, color: Colors.white),
                const SizedBox(width: 12),
                Container(width: 200, height: 14, color: Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 24, height: 24, color: Colors.white),
                const SizedBox(width: 12),
                Container(width: 150, height: 14, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
