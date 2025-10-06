import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Check Thang App',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey.shade800,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Check Thang'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? _reportData;
  File? _selectedImage;
  bool _isUploading = false;
  String? _predictionResult;

  Future<void> _navigateToCameraScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (!mounted || result == null || result is! Map<String, dynamic>) return;

    setState(() {
      _reportData = result;
      _selectedImage = File(result['imagePath']);
      _predictionResult = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('บันทึกข้อมูลภาพและพิกัดสำเร็จ!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _uploadReport() async {
    if (_reportData == null || _selectedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final body = {
        "image": base64Image,
        "location": {
          "lat": _reportData!['latitude'],
          "lng": _reportData!['longitude'],
        },
        "timestamp": _reportData!['timestamp'],
      };
      debugPrint("Sending JSON to Backend AI...");

      final url = Uri.parse(
        'https://g3tuesm.consolutechcloud.com/backend/predict',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _predictionResult = responseBody['danger_level'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ส่งรายงานสำเร็จ! ผลการประเมิน: ${_predictionResult ?? "N/A"}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          'Failed to get prediction from server. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("UploadReport error: $e");
      setState(() {
        _predictionResult = 'Error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งรายงาน: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Widget _buildPredictionChip(String? result) {
    if (result == null) return const SizedBox.shrink();

    Color chipColor;
    IconData chipIcon;
    String displayResult = result;

    switch (result.toLowerCase()) {
      case 'high':
        chipColor = Colors.orange.shade800;
        chipIcon = Icons.warning_amber;
        break;
      case 'mediem':
        chipColor = Colors.amber.shade700;
        chipIcon = Icons.info_outline;
        displayResult = 'Medium';
        break;
      case 'low':
        chipColor = Colors.green.shade700;
        chipIcon = Icons.check_circle_outline;
        displayResult = 'Low';
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.question_mark;
        displayResult = 'ไม่ทราบผล';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'ผลประเมิน: $displayResult',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _selectedImage == null
                      ? Container(
                          height: 300,
                          color: Colors.black26,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ยังไม่มีรูปภาพ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.file(
                          _selectedImage!,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                  Positioned(
                    bottom: 16,
                    child: _buildPredictionChip(_predictionResult),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_reportData != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'พิกัด: ${_reportData!['latitude'].toStringAsFixed(5)}, ${_reportData!['longitude'].toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'เวลา: ${DateFormat("dd MMM yyyy • HH:mm").format(DateTime.parse(_reportData!['timestamp']).toLocal())}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _selectedImage == null ? "เริ่มถ่ายภาพ" : "ถ่ายภาพใหม่",
              ),
              onPressed: _navigateToCameraScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null)
              ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3.0,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? "กำลังส่ง..." : "ส่งรายงาน"),
                onPressed: _isUploading || _predictionResult != null
                    ? null
                    : _uploadReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}