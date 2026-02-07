
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../language/viewmodels/language_vm.dart';
import '../../navigation/views/main_navigator.dart';

class RideSummaryScreen extends StatefulWidget {
  final String rideId;
  final double fare;
  final String driverName;

  const RideSummaryScreen({
    super.key,
    required this.rideId,
    required this.fare,
    required this.driverName,
  });

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _feltSafe = true; // Added Safety Feedback Variable

  double _displayFare = 0.0;
  bool _loadingFare = true;

  @override
  void initState() {
    super.initState();
    _displayFare = widget.fare;
    _fetchFinalFare();
  }

  Future<void> _fetchFinalFare() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(widget.rideId)
          .get();

      if (!doc.exists || doc.data() == null) {
        if (mounted) setState(() => _loadingFare = false);
        return;
      }

      final double finalFare =
          (doc.data()?['fare'] as num?)?.toDouble() ?? widget.fare;

      if (mounted) {
        setState(() {
          _displayFare = finalFare;
          _loadingFare = false;
        });
      }
    } catch (e) {
      debugPrint("Fare refresh failed: $e");
      if (mounted) setState(() => _loadingFare = false);
    }
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(widget.rideId)
          .get();

      final String? driverId = rideDoc.data()?['driverId'];
      if (driverId == null) throw Exception("Driver not found");

      final driverRef = FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId);
      final rideRef = FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(widget.rideId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final driverSnapshot = await transaction.get(driverRef);
        if (!driverSnapshot.exists) throw Exception("Driver missing");

        final data = driverSnapshot.data()!;

        final double ratingSum = (data['ratingSum'] as num?)?.toDouble() ?? 0.0;
        final int ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

        final newSum = ratingSum + _rating;
        final newCount = ratingCount + 1;

        transaction.update(driverRef, {
          'rating': newSum / newCount,
          'ratingSum': newSum,
          'ratingCount': newCount,
        });

        transaction.update(rideRef, {
          'rating': _rating,
          'review': _commentController.text.trim(),
          'feltSafe': _feltSafe,
          'status': 'closed',
        });
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(lang.getText('ride_summary')),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.flag, color: Colors.red),
            label: Text(lang.getText('report_issue'), style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              final Uri emailLaunch = Uri(
                scheme: 'mailto',
                path: 'support@Rurboo.com',
                query: Uri.encodeFull(
                  'subject=Report Ride ${widget.rideId}'
                  '&body=Ride ID: ${widget.rideId}\n'
                  'Driver: ${widget.driverName}\n\n'
                  'Describe the issue below:\n',
                ),
              );

              if (await canLaunchUrl(emailLaunch)) {
                await launchUrl(emailLaunch);
              }
            },
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              Text(
                lang.getText('ride_arrived_title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "${lang.getText('ride_arrived_subtitle')} ${widget.driverName}.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      lang.getText('total_fare'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _loadingFare
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Text(
                            "₹${_displayFare.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(lang.getText('payment_mode_label')),
                        Row(
                          children: [
                            const Icon(Icons.money, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              lang.getText('cash'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Safety Question
              Container(
                decoration: BoxDecoration(
                   color: _feltSafe ? Colors.green[50] : Colors.red[50],
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: _feltSafe ? Colors.green.shade200 : Colors.red.shade200),
                ),
                child: SwitchListTile(
                   title: Text(lang.getText('safe_ride_question'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   value: _feltSafe,
                   activeTrackColor: Colors.green,
                   activeThumbColor: Colors.green,
                   inactiveThumbColor: Colors.red,
                   inactiveTrackColor: Colors.red[200],
                   onChanged: (val) {
                      setState(() => _feltSafe = val);
                      if (!val) {
                         ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(lang.getText('unsafe_feedback'))),
                         );
                      }
                   },
                   secondary: Icon(
                       _feltSafe ? Icons.security : Icons.warning_amber_rounded,
                       color: _feltSafe ? Colors.green : Colors.red,
                   ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                lang.getText('rate_driver'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              RatingBar.builder(
                initialRating: 5,
                minRating: 1,
                allowHalfRating: true,
                itemCount: 5,
                itemBuilder: (context, index) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (r) => setState(() => _rating = r),
              ),

              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: lang.getText('add_comment'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          lang.getText('submit_review'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
