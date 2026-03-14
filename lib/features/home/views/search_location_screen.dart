import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/core/services/user_preferences.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';

import '../viewmodels/home_viewmodel.dart';
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
    // Read the current language BEFORE creating the provider so Google API
    // returns results in the correct language (e.g., Hindi place names in Hindi mode).
    final currentLanguage = Provider.of<LanguageViewModel>(context, listen: false).language;

    return ChangeNotifierProvider(
      create: (_) => SearchLocationViewModel(
        repo: SearchRepository(),
        isDestinationMode: isDestination,
        language: currentLanguage,
      )..init(existingPickupAddress, existingDestinationAddress),
      child: const _SearchLocationBody(),
    );
  }
}

class _SearchLocationBody extends StatefulWidget {
  const _SearchLocationBody();

  @override
  State<_SearchLocationBody> createState() => _SearchLocationBodyState();
}

class _SearchLocationBodyState extends State<_SearchLocationBody> {
  List<LocationResult> _savedFavourites = [];

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final favs = await UserPreferences.getFavorites();
    if (mounted) setState(() => _savedFavourites = favs);
  }

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
                  Navigator.pop(context, {
                    'result': result,
                    'isDestination': vm.isDestinationMode,
                  });
               }
            },
          ),
          const Divider(height: 1),

          _quickAccessButtons(context, vm, lang),
          const Divider(height: 1),

          // Saved Favourites Section
          if (_savedFavourites.isNotEmpty) ...[
            _savedFavouritesSection(context, lang),
            const Divider(height: 1),
          ],

          if (vm.loading) const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: vm.suggestions.isEmpty
                ? Center(
                    child: Text(
                      lang.getText('search_results_hint'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: vm.suggestions.length,
                    itemBuilder: (context, index) {
                      final place = vm.suggestions[index];

                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(place.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.bookmark_border, color: Colors.grey),
                          tooltip: 'Save location',
                          onPressed: () async {
                            final LocationResult? result = await vm.selectPlace(place.placeId!);
                            if (result != null && context.mounted) {
                          showSaveLocationSheet(context, result, lang, onSaved: _loadFavourites);
                            }
                          },
                        ),
                    onTap: () async {
                          final LocationResult? result = await vm.selectPlace(place.placeId!);
                          if (result != null && context.mounted) {
                            Navigator.pop(context, {
                              'result': result,
                              'isDestination': vm.isDestinationMode,
                            });
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
          // ── Pickup field — always editable ───────────────────────────
          TextField(
            controller: vm.pickupController,
            focusNode: vm.pickupFocus,
            onChanged: (text) {
              vm.switchMode(false);   // Switch to pickup search mode
              vm.onTextChanged(text);
              setState(() {}); // Update to show/hide clear icon
            },
            onTap: () => vm.switchMode(false),
            decoration: InputDecoration(
              hintText: lang.getText('search_pickup_placeholder'),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 14),
              suffixIcon: vm.pickupController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        vm.pickupController.clear();
                        vm.onTextChanged('');
                        setState(() {});
                      },
                    )
                  : (!vm.isDestinationMode
                      ? const Icon(Icons.edit, size: 14, color: Colors.green)
                      : null),
            ),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),

          const Divider(height: 1),

          // ── Destination field — always editable ──────────────────────
          TextField(
            controller: vm.destinationController,
            focusNode: vm.destinationFocus,
            onChanged: (text) {
              vm.switchMode(true);    // Switch to destination search mode
              vm.onTextChanged(text);
              setState(() {}); // Update to show/hide clear icon
            },
            onTap: () => vm.switchMode(true),
            decoration: InputDecoration(
              hintText: lang.getText('search_destination_placeholder'),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.square, color: Colors.red, size: 14),
              suffixIcon: vm.destinationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        vm.destinationController.clear();
                        vm.onTextChanged('');
                        setState(() {});
                      },
                    )
                  : (vm.isDestinationMode
                      ? const Icon(Icons.edit, size: 14, color: Colors.red)
                      : null),
            ),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }



  /// Home + Work quick access buttons
  Widget _quickAccessButtons(BuildContext context, SearchLocationViewModel vm, LanguageViewModel lang) {
    return Row(
      children: [
        _quickItem(
          icon: Icons.home,
          label: lang.getText('home'),
          onTap: () async {
            final loc = await UserPreferences.getHomeLocation();
            if (loc != null && context.mounted) {
              Navigator.pop(context, {'result': loc, 'isDestination': vm.isDestinationMode});
            }
          },
        ),
        _quickItem(
          icon: Icons.work,
          label: lang.getText('work'),
          onTap: () async {
            final loc = await UserPreferences.getWorkLocation();
            if (loc != null && context.mounted) {
              Navigator.pop(context, {'result': loc, 'isDestination': vm.isDestinationMode});
            }
          },
        ),
      ],
    );
  }

  Widget _quickItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }

  /// Horizontally scrollable saved favourites chips
  Widget _savedFavouritesSection(BuildContext context, LanguageViewModel lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            lang.getText('favorites'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _savedFavourites.length,
            itemBuilder: (context, index) {
              final fav = _savedFavourites[index];
              return GestureDetector(
                onTap: () => Navigator.pop(context, fav),
                onLongPress: () async {
                  // Long press to delete
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(lang.getText('delete')),
                      content: Text(fav.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.getText('uiCancel'))),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(lang.getText('uiDelete'), style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await UserPreferences.removeFavorite(fav.address);
                    _loadFavourites();
                  }
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite, size: 20, color: Colors.deepPurple),
                      const SizedBox(height: 4),
                      Text(
                        fav.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shows a bottom sheet to save a location as Home, Work, or Favourite.
/// Public so it can also be called from home_screen.dart (pickup pill save button).
void showSaveLocationSheet(
  BuildContext context,
  LocationResult result,
  LanguageViewModel lang, {
  VoidCallback? onSaved,
}) {
  final homeVM = Provider.of<HomeViewModel>(context, listen: false);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.getText('save_location'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(result.address, style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue),
            title: Text(lang.getText('home')),
            onTap: () async {
              await homeVM.saveAsHome(result);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang.getText('location_saved'))),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.work, color: Colors.orange),
            title: Text(lang.getText('work')),
            onTap: () async {
              await homeVM.saveAsWork(result);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang.getText('location_saved'))),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(lang.getText('favorites')),
            onTap: () async {
              await homeVM.toggleFavorite(result);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                onSaved?.call(); // Refresh favourites list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang.getText('location_saved'))),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
