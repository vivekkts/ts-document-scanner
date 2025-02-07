import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class DocumentScannerScreen extends StatefulWidget {
  @override
  _DocumentScannerScreenState createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  List<XFile> capturedImages = [];
  int selectedImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Scanner'),
      ),
      body: Stack(
        children: [
          CameraPreviewPlaceholder(),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: captureImage,
                  child: Icon(Icons.camera_alt, size: 40),
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(15),
                  ),
                ),
                SizedBox(height: 10),
                Text('Manual / Auto Capture', style: TextStyle(color: Colors.white)),
              ],
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PreviewScreen(
                capturedImages: capturedImages,
                selectedImageIndex: selectedImageIndex,
              ),
            ),
          );
        },
        child: Icon(Icons.preview),
      ),
    );
  }

  void captureImage() {
    // Implement image capture logic
    print('Image captured');
  }
}

class PreviewScreen extends StatefulWidget {
  final List<XFile> capturedImages;
  final int selectedImageIndex;

  PreviewScreen({required this.capturedImages, required this.selectedImageIndex});

  @override
  _PreviewScreenState createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late int selectedImageIndex;

  @override
  void initState() {
    super.initState();
    selectedImageIndex = widget.selectedImageIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: widget.capturedImages.length,
              controller: PageController(initialPage: selectedImageIndex),
              onPageChanged: (index) {
                setState(() {
                  selectedImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return ImagePlaceholder(); // Replace with image rendering logic
              },
            ),
          ),
          SizedBox(height: 10),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.capturedImages.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.capturedImages.length) {
                  return AddNewImageButton();
                }
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedImageIndex = index;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: ImagePlaceholderThumbnail(), // Replace with thumbnail rendering logic
                  ),
                );
              },
            ),
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ActionButton(icon: Icons.crop, label: 'Crop & Rotate', onPressed: () {}),
              ActionButton(icon: Icons.filter, label: 'Filter', onPressed: () {}),
              ActionButton(icon: Icons.cleaning_services, label: 'Clean', onPressed: () {}),
              ActionButton(icon: Icons.camera, label: 'Retake', onPressed: () {}),
              ActionButton(icon: Icons.delete, label: 'Delete', onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class CameraPreviewPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Camera Preview Placeholder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey,
      child: Center(
        child: Text('Image Placeholder'),
      ),
    );
  }
}

class ImagePlaceholderThumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      color: Colors.grey,
      child: Center(
        child: Text('Thumbnail'),
      ),
    );
  }
}

class AddNewImageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(Icons.add, color: Colors.blue),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
        ),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
