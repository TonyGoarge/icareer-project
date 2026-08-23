import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'ride_status_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isCheckingActiveRide = true;
  Map<String, dynamic>? _activeRide;
  Map<String, dynamic>? _pendingRideRequest; // Temp container for selection before confirm

  @override
  void initState() {
    super.initState();
    _checkActiveRide();
  }

  Future<void> _checkActiveRide() async {
    setState(() => _isCheckingActiveRide = true);
    try {
      final ride = await ApiService.getActiveRide();
      if (ride != null && (ride['status'] == 'Searching' || ride['status'] == 'Driver Found')) {
        setState(() {
          _activeRide = ride;
          _pendingRideRequest = null;
        });
      } else {
        setState(() {
          _activeRide = null;
        });
      }
    } catch (_) {}
    setState(() => _isCheckingActiveRide = false);
  }

  void _proceedToRequest() {
    if (!_formKey.currentState!.validate()) return;

    // Simulate price estimation page locally first
    setState(() {
      _pendingRideRequest = {
        'pickup': _pickupController.text.trim(),
        'destination': _destinationController.text.trim(),
        'estimatedPrice': 15 + (17.5 * (_pickupController.text.length % 3)).floor(),
      };
    });
  }

  Future<void> _confirmRide() async {
    if (_pendingRideRequest == null) return;

    setState(() => _isCheckingActiveRide = true);
    try {
      final ride = await ApiService.requestRide(
        _pendingRideRequest!['pickup'],
        _pendingRideRequest!['destination'],
      );

      if (ride != null) {
        setState(() {
          _activeRide = ride;
          _pendingRideRequest = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error requesting ride. Try again.')),
        );
      }
    }
    if (mounted) {
      setState(() => _isCheckingActiveRide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingActiveRide) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeRide != null) {
      return RideStatusScreen(
        ride: _activeRide!,
        onClose: () {
          setState(() {
            _activeRide = null;
          });
          _checkActiveRide();
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Ride'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await ApiService.logout();
              widget.onLogout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pendingRideRequest == null) ...[
              const Card(
                color: Color(0xFF1E1E24),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.map, size: 40, color: Color(0xFF39A0ED)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Where are you going today?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Enter pickup and destination to calculate fare.',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _pickupController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Location',
                        prefixIcon: Icon(Icons.my_location, color: Colors.greenAccent),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter pickup location' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.location_on, color: Colors.redAccent),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter destination' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _proceedToRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF39A0ED),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Show Estimated Price', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              Card(
                color: const Color(0xFF1E1E24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 28, color: Color(0xFF39A0ED)),
                          SizedBox(width: 8),
                          Text('Ride Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white24),
                      Row(
                        children: [
                          const Icon(Icons.my_location, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'From: ${_pendingRideRequest!['pickup']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'To: ${_pendingRideRequest!['destination']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Fare:', style: TextStyle(fontSize: 16, color: Colors.white60)),
                          Text(
                            '\$${_pendingRideRequest!['estimatedPrice']}.00',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _confirmRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _pendingRideRequest = null;
                  });
                },
                child: const Text('Cancel & Go Back', style: TextStyle(color: Colors.white60)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
