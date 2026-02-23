import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/core/services/user_preferences.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';

import '../viewmodels/search_location_viewmodel.dart';
import '../repositories/search_repository.dart';
import '../models/location_result.dart';
import 'map_picker_screen.dart'; // Added

class SearchLocationScreen extends StatelessWidget {
  final bool isDestination;
  final String? existingPickupAddress;
  final String? existingDestinationAddress;

  const SearchLocationScreen({
    super.key,
    required this.isDestination,
    this.existingPickupAddress,
    this.existingDestinationAddress,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchLocationViewModel(
        repo: SearchRepository(),
        isDestinationMode: isDestination,
      )..init(existingPickupAddress, existingDestinationAddress),
      child: const _SearchLocationBody(),
    );
  }
}

class _SearchLocationBody extends StatelessWidget {
  const _SearchLocationBody();

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<SearchLocationViewModel>(context);
    final lang = Provider.of<LanguageViewModel>(context);

    final title = vm.isDestinationMode
        ? lang.getText('set_destination')
        : lang.getText('set_pickup');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _searchBox(vm, lang),
          
          // "Choose on Map" Option
          ListTile(
            leading: const Icon(Icons.map, color: Colors.blue),
            title: Text(
              lang.getText('choose_on_map'), 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
            onTap: () async {
               final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerScreen()),
               );
               
               if (result != null && context.mounted) {
                  Navigator.pop(context, result);
               }
            },
          ),
          const Divider(height: 1),

          _favoriteButtons(context, vm, lang),
          const Divider(height: 1),

          if (vm.loading) const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: vm.suggestions.isEmpty
                ? const Center(
                    child: Text(
                      "Search to see results",
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: vm.suggestions.length,
                    itemBuilder: (context, index) {
                      final place = vm.suggestions[index];

                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(place.address),
                        onTap: () async {
                          final LocationResult? result = await vm.selectPlace(
                            place.placeId!,
                          );

                          if (result != null && context.mounted) {
                            Navigator.pop(context, result);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(SearchLocationViewModel vm, LanguageViewModel lang) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        children: [
          TextField(
            controller: vm.pickupController,
            readOnly: vm.isDestinationMode,
            focusNode: vm.pickupFocus,
            onChanged: vm.isDestinationMode ? null : vm.onTextChanged,
            decoration: InputDecoration(
              hintText: lang.getText('pickup_location'),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 14),
            ),
          ),

          const Divider(),

          TextField(
            controller: vm.destinationController,
            readOnly: !vm.isDestinationMode,
            focusNode: vm.destinationFocus,
            onChanged: vm.isDestinationMode ? vm.onTextChanged : null,
            decoration: InputDecoration(
              hintText: lang.getText('where_to'),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.square, color: Colors.red, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _favoriteButtons(BuildContext context, SearchLocationViewModel vm, LanguageViewModel lang) {
    return Row(
      children: [
        _favItem(
          icon: Icons.home,
          label: lang.getText('home'),
          onTap: () async {
            final loc = await UserPreferences.getHomeLocation();
            if (loc != null && context.mounted) {
              Navigator.pop(context, loc);
            }
          },
        ),
        _favItem(
          icon: Icons.work,
          label: lang.getText('work'),
          onTap: () async {
            final loc = await UserPreferences.getWorkLocation();
            if (loc != null && context.mounted) {
              Navigator.pop(context, loc);
            }
          },
        ),
      ],
    );
  }

  Widget _favItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}
