import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../language/viewmodels/language_vm.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodels/history_viewmodel.dart';
import '../models/ride_history_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryViewModel()..fetchRideHistory(),
      child: const _HistoryScreenBody(),
    );
  }
}

class _HistoryScreenBody extends StatelessWidget {
  const _HistoryScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          Provider.of<LanguageViewModel>(context).getText('ride_history'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 1,
      ),
      body: Consumer<HistoryViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => const SkeletonRideCard(),
            );
          }

          if (vm.errorMessage != null) {
            return Center(child: Text(vm.errorMessage!));
          }
          if (vm.rideHistory.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildHistoryList(vm.rideHistory);
        },
      ),
    );
  }

  Widget _buildHistoryList(List<RideHistoryModel> history) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final ride = history[index];
        return _buildHistoryCard(context, ride);
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, RideHistoryModel ride) {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final bool isCompleted =
        ride.status == 'completed' || ride.status == 'closed';
    final Color statusColor = isCompleted ? Colors.green : Colors.red;
    final String displayStatus = isCompleted 
        ? lang.getText('status_completed') 
        : lang.getText('status_cancelled');

    final String formattedDate = DateFormat(
      'MMM d, yyyy • hh:mm a',
    ).format(ride.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  '₹${ride.fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            _buildAddressRow(context, Icons.circle, Colors.green, ride.pickupAddress),
            const SizedBox(height: 12),
            _buildAddressRow(context, Icons.square, Colors.red, ride.destinationAddress),

            const SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  _getRideIcon(ride.rideType),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  ride.rideType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(BuildContext context, IconData icon, Color color, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getRideIcon(String rideType) {
    if (rideType.toLowerCase().contains('bike')) return Icons.two_wheeler;
    if (rideType.toLowerCase().contains('auto')) return Icons.electric_rickshaw;
    return Icons.local_taxi;
  }

  Widget _buildEmptyState(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            lang.getText('no_rides'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            lang.getText('history_empty_desc'),
            style: const TextStyle(),
          ),
        ],
      ),
    );
  }
}
