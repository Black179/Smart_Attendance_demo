import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:math';

class DriverBLEScanner extends StatefulWidget {
  const DriverBLEScanner({super.key});

  @override
  State<DriverBLEScanner> createState() => _DriverBLEScannerState();
}

class _DriverBLEScannerState extends State<DriverBLEScanner> {
  List<Map<String, dynamic>> _scanResults = [];
  bool _isScanning = false;
  Timer? _scanTimer;
  final Random _random = Random();

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  // Simulate BLE device discovery for demo purposes
  void _startScan() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    _showSnackBar("Scanning for BLE devices...", Colors.blue);

    // Simulate discovering devices over time
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick <= 10) { // Scan for 10 seconds
        _addSimulatedDevice();
      } else {
        _stopScan();
      }
    });
  }

  void _addSimulatedDevice() {
    final deviceNames = [
      'Student Phone ${_random.nextInt(100)}',
      'iPhone ${_random.nextInt(20)}',
      'Samsung Galaxy ${_random.nextInt(30)}',
      'OnePlus ${_random.nextInt(15)}',
      'Xiaomi ${_random.nextInt(25)}',
      'Unknown Device',
    ];

    final device = {
      'device_id': 'BLE_${_random.nextInt(10000).toString().padLeft(4, '0')}',
      'name': deviceNames[_random.nextInt(deviceNames.length)],
      'rssi': -30 + _random.nextInt(50), // RSSI between -30 and -80
      'timestamp': DateTime.now().toIso8601String(),
      'manufacturer_data': 'Demo Data',
      'service_uuids': ['12345678-1234-1234-1234-123456789abc'],
    };

    setState(() {
      // Avoid duplicates
      if (!_scanResults.any((d) => d['device_id'] == device['device_id'])) {
        _scanResults.add(device);
      }
    });
  }

  void _stopScan() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
    _showSnackBar("Scan completed - Found ${_scanResults.length} devices", Colors.green);
  }

  Future<void> _saveScanResults() async {
    if (_scanResults.isEmpty) {
      _showSnackBar("No devices to save", Colors.orange);
      return;
    }

    try {
      final box = await Hive.openBox('ble_devices');
      await box.put('last_scan', _scanResults);
      await box.put('scan_timestamp', DateTime.now().toIso8601String());
      
      _showSnackBar("Saved ${_scanResults.length} devices to cache", Colors.green);
    } catch (e) {
      _showSnackBar("Error saving scan results: $e", Colors.red);
    }
  }

  Future<void> _loadSavedDevices() async {
    try {
      final box = await Hive.openBox('ble_devices');
      final savedDevices = List<Map<String, dynamic>>.from(box.get('last_scan', defaultValue: []));
      final scanTimestamp = box.get('scan_timestamp', defaultValue: '');
      
      if (savedDevices.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Saved BLE Devices'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scanTimestamp.isNotEmpty)
                    Text(
                      'Last scan: ${_formatDateTime(scanTimestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: savedDevices.length,
                      itemBuilder: (context, index) {
                        final device = savedDevices[index];
                        return ListTile(
                          leading: Icon(Icons.bluetooth, color: Colors.blue.shade600),
                          title: Text(device['name']?.toString() ?? 'Unknown'),
                          subtitle: Text('ID: ${device['device_id']?.toString() ?? 'N/A'}\nRSSI: ${device['rssi']?.toString() ?? 'N/A'} dBm'),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        _showSnackBar("No saved devices found", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("Error loading saved devices: $e", Colors.red);
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Device Scanner (Demo)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _loadSavedDevices,
            tooltip: 'View Saved Devices',
          ),
        ],
      ),
      body: Column(
        children: [
          // Demo Notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo Mode: Simulated BLE device discovery. Real BLE requires platform permissions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Status and Controls
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BLE Scanner Ready',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (_isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !_isScanning ? _startScan : null,
                        icon: const Icon(Icons.search),
                        label: const Text('Start Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? _stopScan : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scanResults.isNotEmpty ? _saveScanResults : null,
                    icon: const Icon(Icons.save),
                    label: Text('Save Scan (${_scanResults.length} devices)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Device List
          Expanded(
            child: _scanResults.isEmpty
                ? _buildEmptyState()
                : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning ? 'Scanning for devices...' : 'No devices found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning 
                ? 'Please wait while we discover nearby BLE devices'
                : 'Tap "Start Scan" to discover nearby BLE devices',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final device = _scanResults[index];
        final deviceName = device['name']?.toString() ?? 'Unknown Device';
        final rssi = device['rssi'] as int? ?? -80;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Icon(
                Icons.bluetooth,
                color: Colors.teal.shade700,
              ),
            ),
            title: Text(
              deviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${device['device_id']}'),
                Text('RSSI: $rssi dBm'),
                Text(
                  'Services: ${(device['service_uuids'] as List?)?.length ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRSSIColor(rssi).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRSSIStrength(rssi),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getRSSIColor(rssi),
                ),
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Color _getRSSIColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  String _getRSSIStrength(int rssi) {
    if (rssi >= -50) return 'Strong';
    if (rssi >= -70) return 'Medium';
    return 'Weak';
  }
}
