import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:loading_indicator/loading_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';

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
        backgroundColor: Colors.black,
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
  late File selectedVideo;
  String localPath = "";
  bool succeed = false;
  late ChewieController _chewieController;

  @override
  void initState() {
    _chewieController = ChewieController(
      autoPlay: true,
      videoPlayerController: VideoPlayerController.file(File(localPath)),
      aspectRatio: 16 / 9, // Set your desired aspect ratio
      autoInitialize: true,
      looping: false,
      allowedScreenSleep: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white,
      ),
    );

    getPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  _pickVideo();
                },
                child: const Text("Choose Video"),
              ),
            ),
          ),
          if(succeed) SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height / 2,
              child: Chewie(controller: _chewieController),
            ),
         if(succeed) IconButton(
            onPressed: () {
              setState(() {
                _chewieController.isPlaying
                    ? _chewieController.pause()
                    : _chewieController.play();
              });
            },
            icon: Icon(
              _chewieController.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chewieController.dispose();
    super.dispose();
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
        await prepareChewie();
        setState(() {
          succeed = true;
        });
        // The response should contain the converted video or other data
        var responseData = await response.stream.toBytes();
        var decodedData = jsonDecode(utf8.decode(responseData));
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
      Permission.videos,
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
      final appDocumentDirectory = await getExternalStorageDirectory();
      final file = File('${appDocumentDirectory?.path}/converted_video.mp4');
      localPath = '${appDocumentDirectory?.path}/converted_video.mp4';
      await file.writeAsBytes(decodedBytes);

      GallerySaver.saveVideo(localPath).then((value) {
        showToast('Video Saved !');
      });
      print('Video saved to: ${file.path}');
    } catch (e) {
      print('Error saving video to storage: $e');
      return showToast('Error saving video. Please try again.');
    }
  }

  dynamic showToast(String message) {
    return Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> prepareChewie() async {
    final appDocumentDirectory = await getExternalStorageDirectory();
    _chewieController = ChewieController(
      videoPlayerController: VideoPlayerController.file(File('${appDocumentDirectory?.path}/converted_video.mp4')),
      aspectRatio: 16 / 9, // Set your desired aspect ratio
      autoInitialize: true,
      looping: false,
      allowedScreenSleep: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white,
      ),
    );
  }
}