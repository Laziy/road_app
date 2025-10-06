import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // <<< เพิ่ม import นี้

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late List<CameraDescription> _cameras;
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isProcessing = false; // <<< เพิ่ม State สำหรับสถานะ Loading

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('ไม่พบกล้องบนอุปกรณ์');

      final backCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(backCam, ResolutionPreset.high);
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดกล้องไม่สำเร็จ: $e')));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // vvvv เราจะแก้ไขฟังก์ชันนี้เป็นหลัก vvvv
  Future<void> _takePictureAndGetData() async {
    if (!_controller.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true; // เริ่มประมวลผล, แสดง Loading
    });

    try {
      // 1. ถ่ายภาพ
      final XFile imageFile = await _controller.takePicture();

      // 2. ดึงพิกัด GPS
      final Position position = await _getCurrentLocation();

      // 3. บันทึกเวลา
      final DateTime timestamp = DateTime.now();

      // 4. รวมข้อมูลทั้งหมดไว้ใน Map
      final Map<String, dynamic> resultData = {
        'imagePath': imageFile.path,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': timestamp.toIso8601String(),
      };

      // 5. ส่งข้อมูลทั้งหมดกลับไปหน้าหลัก
      if (mounted) {
        Navigator.pop(context, resultData);
      }
    } catch (e) {
      print('Error processing data: $e');
      setState(() {
        _isProcessing = false; // ปิด Loading ถ้าเกิดข้อผิดพลาด
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  // <<< เพิ่มฟังก์ชันสำหรับดึง GPS >>>
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller),
          // แสดง Loading Indicator ขณะกำลังดึง GPS
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'กำลังบันทึกพิกัด...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          // ปุ่มสำหรับถ่ายภาพ
          if (!_isProcessing) // ซ่อนปุ่มขณะประมวลผล
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FloatingActionButton(
                onPressed: _takePictureAndGetData, // <<< เรียกใช้ฟังก์ชันใหม่
                child: const Icon(Icons.camera_alt),
              ),
            ),
        ],
      ),
    );
  }
}
