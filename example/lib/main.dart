import 'dart:io';
import 'package:document_scanner_example/sample.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:document_scanner/document_scanner.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<String> _pictures = [];
  String _filename = "";
  String _pdfPath = "";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
            child: Column(
          children: [
            ElevatedButton(
                onPressed: onPressed, child: const Text("Add Pictures")),
            ElevatedButton(
                onPressed: onSelectPicturesSelect, child: const Text("Select Pictures")),
            if (_filename.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Filename: $_filename',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            for (var picture in _pictures) Image.file(File(picture)),
            if (_pdfPath.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Generated PDF",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 400,
                child: PDFView(
                  filePath: _pdfPath,
                  enableSwipe: true,
                  autoSpacing: true,
                  swipeHorizontal: true,
                  fitPolicy: FitPolicy.BOTH,
                ),
              ),
            ],
          ],
        )),
      ),
    );
  }

  void onSelectPicturesSelect() async {
    List<String> pictures = [];
    String? filename;

    try {
      final result = await DocumentScanner.selectDocuments(noOfPages: 15);
      //  final result = await DocumentScanner.selectDocuments(
      //    noOfPages: 15, sharedFiles: [], documentType: "pdf");
       print("resultis, $result");

      if (result != null) {
        final pictures = result['croppedImageResults'] as List<String>;
        final filename = result['filename'] as String;

        print("Cropped images: $pictures");
        print("Filename: $filename");

        // Ensure widget is still mounted before calling setState
        if (!mounted) return;

        setState(() {
          _pictures = pictures;
          _filename = filename ?? '';
        });
      } else {
        print("No documents selected");
      }
    } catch (exception) {
      // Handle exception here
      print("Exception occurred: $exception");
    }
  }
  void onPressed() async {
    List<String> pictures;
    try {
      final result = await DocumentScanner.getPictures(noOfPages: 15, isGalleryImportAllowed: true) ?? [];
      print("resultis, $result");
      if(result != null && result is Map<String, dynamic>) {
      final pictures = result['croppedImageResults'] as List<String>;
      final filename = result['filename'] as String;
      if (pictures.isNotEmpty) {
        final pdfPath = await _generatePdfFromImages(pictures);
        if (!mounted) return;
        setState(() {
          _pictures = pictures;
          _pdfPath = pdfPath;
        });
      }

      print("Cropped images: $pictures");
      print("Filename: $filename");

      // Ensure widget is still mounted before calling setState
      if (!mounted) return;

      setState(() {
        _pictures = pictures;
        _filename = filename ?? '';
      });
          //
      // print(pictures);
      // if (!mounted) return;
      // setState(() {
      //   _pictures = pictures;
      // });
    } }catch (exception) {
      // Handle exception here
    }
  }


  Future<String> _generatePdfFromImages(List<String> imagePaths) async {
    final pdfDoc = pw.Document();
    for (var imagePath in imagePaths) {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = pw.MemoryImage(imageBytes);
      pdfDoc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(decodedImage, fit: pw.BoxFit.contain, dpi: 110.0),
          );
        },
      ));
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final pdfFile = File('${outputDir.path}/scanned_document.pdf');
    await pdfFile.writeAsBytes(await pdfDoc.save());
    // Get the size of the created PDF
    final int fileSize = await pdfFile.length();
    final double fileSizeKB = fileSize / 1024;
    final double fileSizeMB = fileSizeKB / 1024;

  //  print("PDF created successfully at: $outputPdfPath");
    print("PDF Size: ${fileSizeKB.toStringAsFixed(2)} KB");
    print("PDF Size: ${fileSizeMB.toStringAsFixed(2)} MB");
    print("PDF Saved at: ${pdfFile.path}");
    return pdfFile.path;
  }
}
