import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RideStatusScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onClose;

  const RideStatusScreen({super.key, required this.ride, required this.onClose});

  @override
  State<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends State<RideStatusScreen> {
  late String _rideId;
  late String _status;
  late String _pickup;
  late String _destination;
  late int _price;
  String _driverName = '';
  String _driverVehicle = '';
  Timer? _statusTimer;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _rideId = widget.ride['_id'] ?? '';
    _status = widget.ride['status'] ?? 'Searching';
    _pickup = widget.ride['pickup'] ?? '';
    _destination = widget.ride['destination'] ?? '';
    _price = widget.ride['estimatedPrice'] ?? 0;
    _driverName = widget.ride['driverName'] ?? '';
    _driverVehicle = widget.ride['driverVehicle'] ?? '';

    // Start polling status every 3 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (_isCancelling || _status == 'Completed' || _status == 'Cancelled') return;

    try {
      final updatedRide = await ApiService.getRideStatus(_rideId);
      if (updatedRide != null && mounted) {
        setState(() {
          _status = updatedRide['status'] ?? _status;
          _driverName = updatedRide['driverName'] ?? _driverName;
          _driverVehicle = updatedRide['driverVehicle'] ?? _driverVehicle;
        });

        if (_status == 'Completed' || _status == 'Cancelled') {
          _statusTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);
    try {
      final res = await ApiService.cancelRide(_rideId);
      if (res != null && mounted) {
        setState(() {
          _status = 'Cancelled';
        });
        _statusTimer?.cancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error cancelling ride.')),
        );
      }
    }
    if (mounted) {
      setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    Widget statusGraphic;

    switch (_status) {
      case 'Searching':
        statusColor = const Color(0xFF39A0ED);
        statusIcon = Icons.search;
        statusGraphic = const Column(
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF39A0ED)),
              ),
            ),
            SizedBox(height: 24),
            Text('Finding nearby drivers...', style: TextStyle(color: Colors.white70)),
          ],
        );
        break;
      case 'Driver Found':
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.directions_car;
        statusGraphic = Card(
          color: const Color(0xFF2A2A32),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF39A0ED),
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName.isNotEmpty ? _driverName : 'David Miller',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _driverVehicle.isNotEmpty ? _driverVehicle : 'Tesla Model 3 (White)',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text('4.9 Rating', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case 'Completed':
        statusColor = Colors.greenAccent;
        statusIcon = Icons.check_circle;
        statusGraphic = const Column(
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.greenAccent),
            SizedBox(height: 16),
            Text('Ride Completed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Thank you for riding with us.', style: TextStyle(color: Colors.white60)),
          ],
        );
        break;
      case 'Cancelled':
      default:
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel;
        statusGraphic = const Column(
          children: [
            Icon(Icons.cancel, size: 80, color: Colors.redAccent),
            SizedBox(height: 16),
            Text('Ride Cancelled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Status'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 12),
                  Text(
                    'Status: $_status',
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: statusGraphic,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Trip Details card
            Card(
              color: const Color(0xFF1E1E24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup: $_pickup', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Destination: $_destination', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Estimated Fare: \$$_price.00', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            if (_status == 'Searching' || _status == 'Driver Found') ...[
              ElevatedButton(
                onPressed: _isCancelling ? null : _cancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Cancel Ride', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
