import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:loading_indicator/loading_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  late String localPath;
  late File selectedVideo;
  bool succeed = false;
  bool isLoading = false;
  late VideoPlayerController _controller;

  @override
  void initState() {
    final appDocumentDirectory = getApplicationDocumentsDirectory();
    getPermissions();
    super.initState();
    _controller = VideoPlayerController.file(File("/data/user/0/com.example.ascii_front/app_flutter/converted_video.mp4"))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                _pickVideo();
              },
              child: const Text("Choose Video"),
            ),
          ),
          if(succeed)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          succeed ? IconButton(onPressed: (){
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          }, icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          )) : const SizedBox()
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedVideo = File(result.files.single.path!);
      });
      // Send the selected video to the Flask app
      await sendVideoToFlask(selectedVideo);
    }
  }

  Future<void> sendVideoToFlask(File video) async {
    String url = 'http://192.168.8.250:5000/convert';
    // Create a multipart request
    var request = http.MultipartRequest('POST', Uri.parse(url));
    // Attach the video file to the request
    request.files.add(await http.MultipartFile.fromPath('file', video.path));
    try {
      // Send the request
      var response = await request.send();
      if (response.statusCode == 200) {
        // The response should contain the converted video or other data
        var responseData = await response.stream.toBytes();
        var decodedData = jsonDecode(utf8.decode(responseData));
        print(decodedData);
        // Save the converted video to the phone's storage
        await saveVideoToStorage(decodedData['video']);
      } else {
        // Handle the error
        print('Failed to send video. Status code: ${response.statusCode}');
        showToast('Failed to convert video. Please try again.');
      }
    } catch (e) {
      print('Error sending video: $e');
      showToast('Error converting video. Please try again.');
    }
  }

  Future<bool> getPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.mediaLibrary,
      Permission.accessMediaLocation,
    ].request();
    var storage = statuses[Permission.storage];
    var manageExternalStorage = statuses[Permission.manageExternalStorage];
    if (storage!.isGranted || manageExternalStorage!.isGranted) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      return true;
    }
    return false;
  }

  Future<void> saveVideoToStorage(String base64Data) async {
    try {
      final decodedBytes = base64.decode(base64Data);
      final appDocumentDirectory = await getApplicationDocumentsDirectory();
      final file = File('${appDocumentDirectory.path}/converted_video.mp4');
      await file.writeAsBytes(decodedBytes);
      print('Video saved to: ${file.path}');
      showToast('Video saved successfully: ${file.path}');
      succeed = true;
    } catch (e) {
      print('Error saving video to storage: $e');
      showToast('Error saving video. Please try again.');
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
