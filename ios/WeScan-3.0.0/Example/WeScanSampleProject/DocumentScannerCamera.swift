import SwiftUI
import WeScan

struct DocumentScannerCameraView: View {
    @State private var showImageEditor = false
    @State private var capturedImage: UIImage?
    @State private var capturedQuad: Quadrilateral?
    @State private var isTorchOn = false
    
    var onImageCaptured: ((UIImage, UIImage, Quadrilateral?) -> Void)?
    var onImageCaptureCancelled: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
        
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
                        if let onImageCaptureCancelled = onImageCaptureCancelled {
                            onImageCaptureCancelled()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Scan a Document")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        NotificationCenter.default.post(name: .toggleFlash, object: nil)
                    }) {
                        Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .background(.black)
            .navigationDestination(isPresented: $showImageEditor) {
                DocumentScannerPreviewView(
                    image: $capturedImage,
                    quad: $capturedQuad
                ) {
                    originalImage, editedImage, quad in
                    if let onImageCaptured = onImageCaptured {
                        onImageCaptured(originalImage, editedImage, quad)
                    }
                    dismiss()
                }
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
            parent.onCaptureSuccess?(image, quad)
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
