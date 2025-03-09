import SwiftUI
import WeScan

struct DocumentScannerCameraView: View {
    @State private var showImageEditor = false
    @State private var capturedImage: UIImage?
    @State private var capturedQuad: Quadrilateral?
    @State private var isTorchOn = false
    @State private var showAlert = false
    
    var onImageCaptured: ((UIImage, UIImage, Quadrilateral?) -> Void)?
    var onImageCaptureCancelled: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss

       init(
             onImageCaptured: ((UIImage, UIImage, Quadrilateral?) -> Void)? = nil,
             onImageCaptureCancelled: (() -> Void)? = nil,
             onDismiss: (() -> Void)? = nil
         ) {
             self.onImageCaptured = onImageCaptured
             self.onImageCaptureCancelled = onImageCaptureCancelled
             self.onDismiss = onDismiss
         }

    var body: some View {
        NavigationStack {
            ZStack {
                Spacer()
                VStack {
                    CameraView(onCaptureSuccess: { image, quad in
                        capturedImage = image
                        capturedQuad = quad
                        showImageEditor = true
                    }, onCaptureFail: { error in
                        print("Error: \(error.localizedDescription)")
                    }, isTorchOn: isTorchOn)
                    .edgesIgnoringSafeArea(.all)
                    .frame(height: UIScreen.main.bounds.size.height * 0.7)
                    
                    Spacer()
                    Button(action: {
                        NotificationCenter.default.post(name: .capturePhoto, object: nil)
                    }) {
                        Image(systemName: "largecircle.fill.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                            .padding(7.5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .tint(.black)
                    .foregroundStyle(.white)
                    
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                     showAlert = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }.alert("Discard Documents?", isPresented: $showAlert) {
                                                               Button("Keep editing", role: .cancel) { } // Do nothing on cancel
                                                               Button("Discard", role: .destructive) {
                                                                   dismiss() // Dismiss the view if user confirms
                                                               }
                                                           } message: {
                                                               Text("If you leave now, Your progress will be lost.")
                                                           }

                }
                
                ToolbarItem(placement: .principal) {
                    Text("Scan a Document")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isTorchOn.toggle()
                        NotificationCenter.default.post(name: .toggleFlash, object: nil)
                    }) {
                        Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .background(.black)
            .navigationDestination(isPresented: $showImageEditor) {
//                DocumentScannerPreviewView(
//                    image: $capturedImage,
//                    quad: $capturedQuad
//                ) {
//                    originalImage, editedImage, quad in
//                    if let onImageCaptured = onImageCaptured {
//                        onImageCaptured(originalImage, editedImage, quad)
//                    }
//                    print("Calling onDismiss in DocumentScannerCameraView")
//                     onDismiss?()
//                    dismiss()
//                }
DocumentScannerPreviewView(
        image: $capturedImage,
        quad: $capturedQuad,
        onImageEdited: { originalImage, editedImage, quad in
            if let onImageCaptured = onImageCaptured {
                onImageCaptured(originalImage, editedImage, quad)
            }
            dismiss()
        },
        onDismiss: {
            print("Calling onDismiss in DocumentScannerCameraView")
            onDismiss?() // Call the onDismiss handler
            dismiss()
        }
    )
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    class Coordinator: NSObject, CameraScannerViewOutputDelegate {
        let parent: CameraView

        init(parent: CameraView) {
            self.parent = parent
        }

        func captureImageFailWithError(error: Error) {
            print("Capture failed with error: \(error)")
        }

        func captureImageSuccess(image: UIImage, withQuad quad: Quadrilateral?) {
             let imageSize = parent.calculateImageSize(image) // Calculate size
                   print("Captured Image Size: \(imageSize) KB (\(String(format: "%.2f", Double(imageSize) / 1024.0)) MB)")


        let compressedImage = compressImage(image: image, quality: 0.5)
         let imageSize3 = parent.calculateImageSize(compressedImage) // Cal
         print("Captured Image Size: \(imageSize3) KB (\(String(format: "%.2f", Double(imageSize3) / 1024.0)) MB)")

            parent.onCaptureSuccess?(compressedImage, quad)
        }

        // Function to compress the image
        func compressImage(image: UIImage, quality: CGFloat) -> UIImage {
            guard let imageData = image.jpegData(compressionQuality: quality),
                  let compressedImage = UIImage(data: imageData) else {
                return image // Return original if compression fails
            }
            return compressedImage
        }
    }


    var onCaptureSuccess: ((UIImage, Quadrilateral?) -> Void)?
    var onCaptureFail: ((Error) -> Void)?
    var isTorchOn: Bool

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.delegate = context.coordinator
        
        NotificationCenter.default.addObserver(forName: .capturePhoto, object: nil, queue: .main) { _ in
            controller.capture()
        }
        
        NotificationCenter.default.addObserver(forName: .toggleFlash, object: nil, queue: .main) { _ in
            controller.toggleFlash()
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        // Update the view controller as needed

    }
      /// **Calculate Image Size in KB**
        func calculateImageSize(_ image: UIImage) -> Int {
            guard let imageData = image.jpegData(compressionQuality: 1.0) else { return 0 }
            return imageData.count / 1024 // Convert bytes to KB
        }
}

struct ImageEditorView: View {
    let image: UIImage
    let quad: Quadrilateral?

    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            Text("Edit Image View")
        }
    }
}

// Common
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
    static let toggleFlash = Notification.Name("toggleFlash")
}

struct DocumentScannerCameraView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentScannerCameraView()
    }
}
