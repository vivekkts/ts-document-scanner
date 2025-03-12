import Flutter
import UIKit
import SwiftUI
import WeScan
import PDFKit

@available(iOS 13.0, *)
public class SwiftDocumentScannerPlugin: NSObject, FlutterPlugin, UIApplicationDelegate {
    var resultChannel: FlutterResult?
    var imagePicker: UIImagePickerController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "document_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>

        if (call.method == "getPictures") {
            print("Hello", "getPictures")
            if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
                self.resultChannel = result

                // Use DocumentScannerCameraView
                let documentScannerCameraView = DocumentScannerCameraView(
                    onImageCaptured: { [weak self] originalImage, editedImage, quad in
                        // Handle captured image
                        if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
                            // Pass captured image to DocumentScannerHome
                            let documentScannerView = DocumentScannerHome(initialImage: editedImage, selectFromGallery: false,
                            onSave: { [weak self] images, name in
                                                                                            print("Camera  image RECEIVED:", images, "NAME:", name)

                                                                                            // Send images and name back to Flutter
                                                                                            self?.resultChannel?(["images": images, "name": name])
                                                                                            self?.resultChannel = nil
                                                                                        })
                            let documentScannerViewController = UIHostingController(rootView: documentScannerView)
        //
        //                    documentScannerViewController.rootView.onSave = { [weak self] images in
        //                        print("IMAGES RECEIVED", images)
        //                        self?.resultChannel?(images)
        //                        self?.resultChannel = nil
        //                    }

                            // Ensure the view controller is in the window hierarchy
                            DispatchQueue.main.async {
                                documentScannerViewController.modalPresentationStyle = .fullScreen
                                viewController.present(documentScannerViewController, animated: true, completion: nil)
                            }
                        }
                    },
                    onImageCaptureCancelled: { [weak self] in
                        // Handle dismissal
                        self?.resultChannel?(FlutterError(code: "CANCELLED", message: "User cancelled image capture", details: nil))
                        self?.resultChannel = nil
                    }
                )

                let documentScannerCameraViewController = UIHostingController(rootView: documentScannerCameraView)
                documentScannerCameraViewController.modalPresentationStyle = .fullScreen

                // Ensure the view controller is in the window hierarchy
                DispatchQueue.main.async {
                    viewController.present(documentScannerCameraViewController, animated: true, completion: nil)
                }
            }
        }

        if call.method == "selectDocuments" {
            print("Hello", "selectDocuments")
            
            if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
                self.resultChannel = result
                
                if let sharedFiles = args["sharedFiles"] as? Array<String>, sharedFiles.count > 0 {
                    print("Shared Files", sharedFiles)
                    if URL(filePath: sharedFiles[0]).pathExtension == "pdf" {
                        // Send PDF file back to Flutter
                        self.resultChannel?(["images": sharedFiles])
                        self.resultChannel = nil
                    }
                    else {
                        // get UIImage from sharedFiles first index
                        let image = UIImage(contentsOfFile: sharedFiles[0])
                        if let image = image {
                            onSelectImage(image)
                        }
                    }
                }
                else {
                    if let documentType = args["documentType"] as? String, documentType == "pdf" {
                        
                        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
                        documentPicker.delegate = self
                        documentPicker.allowsMultipleSelection = false

                        documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen

                        // Ensure the view controller is in the window hierarchy
                        DispatchQueue.main.async {
                            viewController.present(documentPicker, animated: true, completion: nil)
                        }
                    }
                    else {
                        // Use ImagePickerView
                        let imagePickerView = ImagePickerView(
                            onSelect: { [weak self] image in
                                // Handle selected image
                                self?.onSelectImage(image)
                            },
                            onDismiss: { [weak self] in
                                // Handle dismissal
                                self?.resultChannel?(FlutterError(code: "CANCELLED", message: "User cancelled image selection", details: nil))
                                self?.resultChannel = nil
                            }
                        )

                        let imagePickerViewController = UIHostingController(rootView: imagePickerView)
                        imagePickerViewController.modalPresentationStyle = .fullScreen

                        // Ensure the view controller is in the window hierarchy
                        DispatchQueue.main.async {
                            viewController.present(imagePickerViewController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }

    private func onSelectImage(_ image: UIImage) {
        if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
            // Pass selected image to DocumentScannerPreviewView
            let documentScannerPreviewView = DocumentScannerPreviewView(
                image: .constant(image),
                quad: .constant(nil),
                isEditing: true,
                onImageEdited: { [weak self] originalImage, editedImage, quad in
                    // Pass edited image to DocumentScannerHome
                    let documentScannerView = DocumentScannerHome(initialImage: editedImage, selectFromGallery: true,
                    onSave: { [weak self] images, name in
                                                        print("IMAGES RECEIVED:", images, "NAME:", name)

                                                        // Send images and name back to Flutter
                                                        self?.resultChannel?(["images": images, "name": name])
                                                        self?.resultChannel = nil
                                                    })
                    let documentScannerViewController = UIHostingController(rootView: documentScannerView)
                    // Ensure the view controller is in the window hierarchy
                    DispatchQueue.main.async {
                        documentScannerViewController.modalPresentationStyle = .fullScreen
                        viewController.present(documentScannerViewController, animated: true, completion: nil)
                    }
                },
                onDismiss: { [weak self] in
                    // Handle dismissal
                    self?.resultChannel?(FlutterError(code: "CANCELLED", message: "User cancelled editing   selection", details: nil))
                    self?.resultChannel = nil
                }
            )

            let documentScannerPreviewViewController = UIHostingController(rootView: documentScannerPreviewView)
            documentScannerPreviewViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            documentScannerPreviewViewController.modalTransitionStyle = UIModalTransitionStyle.crossDissolve

            // Ensure the view controller is in the window hierarchy
            DispatchQueue.main.async {
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = .push
                transition.subtype = .fromRight // Moves from right to left (East to West)
                viewController.view.window?.layer.add(transition, forKey: kCATransition)
                viewController.present(documentScannerPreviewViewController, animated: true, completion: nil)
            }
        }
    }
}

extension SwiftDocumentScannerPlugin: UIDocumentPickerDelegate {
 public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var paths: [String] = []
        var filename: String = ""

        let tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                let uniqueFilename = "\(UUID().uuidString)_\(url.lastPathComponent)"
                filename=url.lastPathComponent
                let destinationURL = tempDirURL.appendingPathComponent(uniqueFilename)
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    paths.append(destinationURL.path)
                } catch {
                    print("Error copying file: \(error)")
                }
                url.stopAccessingSecurityScopedResource()
            }
        }


        self.resultChannel?(["images": paths,"name":filename])
        self.resultChannel = nil
    }


}



struct ImagePickerView: UIViewControllerRepresentable {
    var onSelect: (UIImage) -> Void
    var onDismiss: () -> Void

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePickerView
        var onSelect: (UIImage) -> Void
        var onDismiss: (() -> Void)?

        init(parent: ImagePickerView, onSelect: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.parent = parent
            self.onSelect = onSelect
            self.onDismiss = onDismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: {[weak self] in
                self?.parent.onDismiss()
            })
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {

                picker.dismiss(animated: true, completion: {[weak self] in
                    self?.parent.onSelect(image)
                })
            } else {
                picker.dismiss(animated: true, completion: {[weak self] in
                    self?.parent.onDismiss()
                })
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onSelect: onSelect, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}


//extension SwiftDocumentScannerPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//
//    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//        picker.dismiss(animated: true) {
//            if let selectedImage = info[.originalImage] as? UIImage {
//                if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
//
//                    // Pass selected image to DocumentScannerHome
//                    let documentScannerView = DocumentScannerHome(initialImage: selectedImage,selectFromGallery: true)
//                    let documentScannerViewController = UIHostingController(rootView: documentScannerView)
//
//                    documentScannerViewController.rootView.onSave = { [weak self] images in
//                        print("IMAGES RECEIVED", images)
//                        self?.resultChannel?(images)
//                        self?.resultChannel = nil
//                    }
//
//                    documentScannerViewController.modalPresentationStyle = .fullScreen
//                    viewController.present(documentScannerViewController, animated: true, completion: nil)
//                }
//            } else {
//                self.resultChannel?(FlutterError(code: "NO_IMAGE_SELECTED", message: "No image was selected", details: nil))
//                self.resultChannel = nil
//            }
//        }
//    }
//
//    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//        picker.dismiss(animated: true, completion: nil)
//        self.resultChannel?(FlutterError(code: "CANCELLED", message: "User cancelled image selection", details: nil))
//        self.resultChannel = nil
//    }
//}
//

