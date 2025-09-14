import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:io';

class DriverBLEScanner extends StatefulWidget {
  const DriverBLEScanner({super.key});

  @override
  State<DriverBLEScanner> createState() => _DriverBLEScannerState();
}

class _DriverBLEScannerState extends State<DriverBLEScanner> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _bluetoothEnabled = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      _showSnackBar("Bluetooth not supported by this device", Colors.red);
      return;
    }

    // Listen to Bluetooth adapter state changes
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bluetoothEnabled = state == BluetoothAdapterState.on;
      });
      
      if (state == BluetoothAdapterState.on) {
        _showSnackBar("Bluetooth enabled", Colors.green);
      } else if (state == BluetoothAdapterState.off) {
        _showSnackBar("Bluetooth disabled", Colors.orange);
        _stopScan();
      }
    });

    // Check current Bluetooth state
    final state = await FlutterBluePlus.adapterState.first;
    setState(() {
      _bluetoothEnabled = state == BluetoothAdapterState.on;
    });
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        _showSnackBar("Bluetooth permissions required for scanning", Colors.red);
        return false;
      }
    }
    return true;
  }

  Future<void> _startScan() async {
    if (!_bluetoothEnabled) {
      _showSnackBar("Please enable Bluetooth first", Colors.orange);
      return;
    }

    if (!await _requestPermissions()) {
      return;
    }

    try {
      setState(() {
        _isScanning = true;
        _scanResults.clear();
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
        });
      });

      // Auto-stop scanning after timeout
      Timer(const Duration(seconds: 15), () {
        if (_isScanning) {
          _stopScan();
        }
      });

      _showSnackBar("Scanning for BLE devices...", Colors.blue);
    } catch (e) {
      _showSnackBar("Error starting scan: $e", Colors.red);
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      setState(() {
        _isScanning = false;
      });
      _showSnackBar("Scan stopped", Colors.grey);
    } catch (e) {
      _showSnackBar("Error stopping scan: $e", Colors.red);
    }
  }

  Future<void> _saveScanResults() async {
    if (_scanResults.isEmpty) {
      _showSnackBar("No devices to save", Colors.orange);
      return;
    }

    try {
      final box = await Hive.openBox('ble_devices');
      
      // Convert scan results to serializable format
      List<Map<String, dynamic>> deviceData = _scanResults.map((result) {
        return {
          'device_id': result.device.remoteId.toString(),
          'name': result.device.platformName.isNotEmpty 
              ? result.device.platformName 
              : 'Unknown Device',
          'rssi': result.rssi,
          'timestamp': DateTime.now().toIso8601String(),
          'manufacturer_data': result.advertisementData.manufacturerData.toString(),
          'service_uuids': result.advertisementData.serviceUuids.map((uuid) => uuid.toString()).toList(),
        };
      }).toList();

      // Save to Hive
      await box.put('last_scan', deviceData);
      await box.put('scan_timestamp', DateTime.now().toIso8601String());
      
      _showSnackBar("Saved ${deviceData.length} devices to cache", Colors.green);
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
                        final device = savedDevices[index] as Map<String, dynamic>;
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
        title: const Text('BLE Device Scanner'),
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
                      _bluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                      color: _bluetoothEnabled ? Colors.teal.shade700 : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _bluetoothEnabled ? 'Bluetooth Enabled' : 'Bluetooth Disabled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _bluetoothEnabled ? Colors.teal.shade700 : Colors.red,
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
                        onPressed: _bluetoothEnabled && !_isScanning ? _startScan : null,
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
        final result = _scanResults[index];
        final device = result.device;
        final deviceName = device.platformName.isNotEmpty 
            ? device.platformName 
            : 'Unknown Device';
        
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
                Text('ID: ${device.remoteId}'),
                Text('RSSI: ${result.rssi} dBm'),
                if (result.advertisementData.serviceUuids.isNotEmpty)
                  Text(
                    'Services: ${result.advertisementData.serviceUuids.length}',
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
                color: _getRSSIColor(result.rssi).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRSSIStrength(result.rssi),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getRSSIColor(result.rssi),
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
