import 'dart:convert';
import 'dart:io';
import 'package:ascii_front/request.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    addFileSelectionListener();
    getPermissions();
    super.initState();
  }

  WebViewController controller = WebViewController()..loadRequest(
  Uri.parse("http://192.168.8.250:5000/"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body:           Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Expanded(child: WebViewWidget(
              controller: controller,
            )
              ,)],
          ),
        ),
      )// This trailing comma makes auto-formatting nicer for build methods.
    );
  }


  void test() async {
    var data = await getData(Uri.parse("http://192.168.8.250:5000/"));
    var decodedData = jsonDecode(data);
    print(decodedData['query']);
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

  void addFileSelectionListener() async {
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  Future<List<String>> _androidFilePicker(final FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return [file.uri.toString()];
    }
    return [];
  }

  Future<void> prepareSaveDir() async {
    localPath = (await findLocalPath())!;
    final savedDir = Directory(localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
    return ;
  }
  Future<String?> findLocalPath() async {
    var externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await getApplicationDocumentsDirectory();
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }
}
