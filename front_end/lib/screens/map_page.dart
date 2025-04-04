import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_finder/services/api_services/auth_det.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:path_finder/providers/event_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  final String baseUrl = AuthDet().baseUrl;
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic>? _selectedLocation;
  bool _showLocationDetails = false;
  List<Map<String, dynamic>> _locationEvents = [];
  bool _loadingEvents = false;

  // Track bottom sheet height for dragging
  double _bottomSheetHeight = 0.0;
  final double _initialBottomSheetHeight = 300.0; // Initial height

  final List<String> _categories = [
    "All",
    "Academics",
    "Hostel",
    "Sports",
    "Eateries",
    "Shopping",
    "Others",
  ];

  String _selectedCategory = 'Academics';

  // Default position (will be updated with user's location when available)
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(
        12.84401131611071, 80.15341209566053), // Center at AB1 by default
    zoom: 18,
  );

  // Add this variable to control map style
  String _mapStyle = '';

  @override
  void initState() {
    super.initState();
    _bottomSheetHeight = _initialBottomSheetHeight;

    // Load custom map style that makes the blue dot more visible
    rootBundle.loadString('assets/map_style.json').then((string) {
      _mapStyle = string;
    }).catchError((error) {
      print("Error loading map style: $error");
    });

    // Request location permissions immediately when screen loads
    _requestLocationPermission();

    // Pre-load events data from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      if (eventProvider.eventList.isEmpty) {
        eventProvider.fetchAllEvents();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Separate method to request location permissions
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage =
            'Location services are disabled. Please enable GPS in settings.';
      });
      _fetchBuildings(
          'All'); // Still fetch buildings even if location is unavailable
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permissions are denied.';
        });
        _fetchBuildings('All');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage =
            'Location permissions are permanently denied. Please enable in app settings.';
      });
      _fetchBuildings('All');
      return;
    }

    // Once permission is granted, fetch location and buildings
    _getUserLocation();
    _fetchBuildings('All');
  }

  // Get user location - enhanced version
  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _initialPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        );
      });

      // Update camera position if map is already created
      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;

        // Apply custom style if available
        if (_mapStyle.isNotEmpty) {
          controller.setMapStyle(_mapStyle);
        }

        // Animate to user location
        controller
            .animateCamera(CameraUpdate.newCameraPosition(_initialPosition));

        // Additional call to show the blue dot
        controller.animateCamera(CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude)));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _fetchBuildings(String category) async {
    try {
      if (category == 'All') {
        final response = await http.get(
          Uri.parse('$baseUrl/api/buildings/'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> buildings = jsonDecode(response.body);
          _addMarkers(buildings);
        } else {
          setState(() {
            _errorMessage = 'Failed to load buildings: ${response.statusCode}';
            _isLoading = false;
          });
        }
      } else {
        final response = await http.get(
          Uri.parse('$baseUrl/api/buildings/category/$category'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> buildings = jsonDecode(response.body);
          _addMarkers(buildings);
        } else {
          setState(() {
            _errorMessage = 'Failed to load buildings : ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _addMarkers(List<dynamic> buildings) {
    setState(() {
      for (var building in buildings) {
        // Skip if the category filter is active and this building doesn't match
        if (_selectedCategory != 'All' &&
            building['category']?.toLowerCase() !=
                _selectedCategory.toLowerCase()) {
          continue;
        }

        final marker = Marker(
          markerId: MarkerId(building['_id']),
          position: LatLng(
            building['coordinates']['lat'],
            building['coordinates']['lng'],
          ),
          infoWindow: InfoWindow(
            title: building['name'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(building['category'] ?? 'others')),
          onTap: () {
            _onMarkerTapped(building);
          },
        );
        _markers.add(marker);
      }
      _isLoading = false;
    });
  }

  double _getMarkerHue(String type) {
    switch (type.toLowerCase()) {
      case 'academics':
        return BitmapDescriptor.hueRed;
      case 'hostel':
        return BitmapDescriptor.hueYellow;
      case 'sports':
        return BitmapDescriptor.hueGreen;
      case 'eateries':
        return BitmapDescriptor.hueCyan;
      case 'shopping':
        return BitmapDescriptor.hueMagenta;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  void _onMarkerTapped(Map<String, dynamic> location) {
    setState(() {
      _selectedLocation = location;
      _showLocationDetails = true;
      _loadingEvents = true;
      _locationEvents = []; // Clear previous events
      _bottomSheetHeight = _initialBottomSheetHeight; // Reset height
    });

    // Fetch events for this location from provider
    _fetchLocationEvents(location['name']);
  }

  // Updated to use EventProvider instead of direct API call
  Future<void> _fetchLocationEvents(String locationName) async {
    setState(() {
      _loadingEvents = true;
    });

    try {
      // Short delay to show loading state
      await Future.delayed(const Duration(milliseconds: 300));

      // Get events from provider
      final eventProvider = Provider.of<EventProvider>(context, listen: false);

      // If provider doesn't have events yet, fetch them
      if (eventProvider.eventList.isEmpty) {
        await eventProvider.fetchAllEvents();
      }

      // Filter events by location name
      final locationEvents = eventProvider.eventList.where((event) {
        // Check if the event's location matches the selected location
        return event['location']?.toString().toLowerCase() ==
                locationName.toLowerCase() ||
            event['roomno']?.toString().toLowerCase() ==
                locationName.toLowerCase();
      }).toList();

      // Update state with filtered events
      if (mounted) {
        setState(() {
          _locationEvents = locationEvents;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationEvents = [];
          _loadingEvents = false;
        });
      }
      print('Error fetching location events: $e');
    }
  }

  void _filterMarkersByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _markers.clear();
      _isLoading = true;
      _showLocationDetails = false;
    });

    _fetchBuildings(category);
  }

  void _onViewEventButtonPressed(Map<String, dynamic> event) {
    // Navigate to event details page
    Navigator.pushNamed(context, '/event_page', arguments: event);
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to transparent with dark icons
    // final location = ModalRoute.of(context)?.settings.arguments as String?;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true, // This should enable the blue dot
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);

              // Apply map style if available to enhance blue dot visibility
              if (_mapStyle.isNotEmpty) {
                controller.setMapStyle(_mapStyle);
              }

              // Try to get location again after map is created
              _getUserLocation();
            },
            onTap: (LatLng position) {
              // Close location detail sheet when tapping on empty map area
              setState(() {
                _showLocationDetails = false;
              });
            },
          ),

          // Header with search and categories
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(
                          Icons.search,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for places...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            hintStyle: TextStyle(color: Colors.grey[400]),
                          ),
                          style: const TextStyle(fontSize: 16),
                          onSubmitted: (value) {
                            // Search functionality here
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),

                // Categories
                Container(
                  height: 50,
                  margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          _filterMarkersByCategory(category);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[700] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Error message
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(224),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _markers.clear();
                          _errorMessage = '';
                        });
                        _requestLocationPermission(); // Try getting location permissions again
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Location details bottom sheet (only shown when a location is selected)
          if (_showLocationDetails && _selectedLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                // Enable dragging
                onVerticalDragUpdate: (details) {
                  setState(() {
                    // Adjust height based on drag, with min and max constraints
                    double newHeight = _bottomSheetHeight - details.delta.dy;
                    _bottomSheetHeight = newHeight.clamp(
                        _initialBottomSheetHeight,
                        MediaQuery.of(context).size.height * 0.7);
                  });
                },
                onVerticalDragEnd: (details) {
                  // Snap to predefined sizes
                  setState(() {
                    // Define snap points
                    final double smallHeight = _initialBottomSheetHeight;
                    final double largeHeight =
                        MediaQuery.of(context).size.height * 0.6;

                    // If dragged up from initial position, snap to large height
                    if (_bottomSheetHeight > smallHeight) {
                      _bottomSheetHeight = largeHeight;
                    } else {
                      _bottomSheetHeight = smallHeight;
                    }
                  });
                },
                child: Container(
                  height: _bottomSheetHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pull indicator
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Location header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              radius: 24,
                              child: Icon(
                                _selectedLocation!['category']?.toLowerCase() ==
                                        'academics'
                                    ? Icons.school
                                    : _selectedLocation!['category']
                                                ?.toLowerCase() ==
                                            'hostel'
                                        ? Icons.hotel
                                        : _selectedLocation!['category']
                                                    ?.toLowerCase() ==
                                                'sports'
                                            ? Icons.sports_soccer
                                            : _selectedLocation!['category']
                                                        ?.toLowerCase() ==
                                                    'eateries'
                                                ? Icons.restaurant
                                                : _selectedLocation!['category']
                                                            ?.toLowerCase() ==
                                                        'shopping'
                                                    ? Icons.shopping_cart
                                                    : Icons.place,
                                color: Colors.blue[700],
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLocation!['name'] ??
                                        'Unknown Location',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_selectedLocation!['type'] != null)
                                    Text(
                                      _capitalizeFirstLetter(
                                          _selectedLocation!['type']),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _showLocationDetails = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      // Divider
                      Divider(
                        thickness: 1,
                        height: 1,
                        color: Colors.grey[200],
                        indent: 35,
                        endIndent: 35,
                      ),

                      SizedBox(height: 10),

                      // Events list
                      _loadingEvents
                          ? Container(
                              height: 150,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            )
                          : _locationEvents.isEmpty
                              ? Container(
                                  height: 150,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_busy,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No events at this location',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    itemCount: _locationEvents.length,
                                    itemBuilder: (context, index) {
                                      final event = _locationEvents[index];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(12),
                                          title: Text(
                                            event['name'] ?? "no name",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                '${event['date']} • ${event['time']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Organized by ${event['clubName']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: ElevatedButton(
                                            onPressed: () =>
                                                _onViewEventButtonPressed(
                                                    event),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue[700],
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                            ),
                                            child: const Text('View'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // Only show floating action buttons when location details are not shown
      // floatingActionButton: _showLocationDetails
      //     ? null // Hide when details are shown
      //     : Column(
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         children: [
      //           FloatingActionButton(
      //             heroTag: 'centerMapButton',
      //             onPressed: () async {
      //               final controller = await _controller.future;
      //               controller.animateCamera(
      //                   CameraUpdate.newCameraPosition(_initialPosition));
      //             },
      //             backgroundColor: Colors.white,
      //             child: Icon(
      //               Icons.center_focus_strong,
      //               color: Colors.blue[700],
      //             ),
      //           ),
      //           const SizedBox(height: 16),
      //           FloatingActionButton(
      //             heroTag: 'myLocationButton',
      //             onPressed: () {
      //               _getUserLocation(); // Use the user location function from map_screen
      //             },
      //             backgroundColor: Colors.white,
      //             child: Icon(
      //               Icons.my_location,
      //               color: Colors.blue[700],
      //             ),
      //           ),
      //         ],
      //       ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
