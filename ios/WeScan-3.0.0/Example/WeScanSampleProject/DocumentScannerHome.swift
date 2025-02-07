import SwiftUI
import WeScan
import Foundation


struct ScannedImage {
    var name: String
    var originalImage: UIImage?
    var croppedImage: UIImage?
    var quad: Quadrilateral?
    var originalImagePath: String?
    var croppedImagePath: String?
    
    init(name: String, originalImage: UIImage, croppedImage: UIImage? = nil, quad: Quadrilateral? = nil) {
        
        let unixTimestamp = String(Int(Date().timeIntervalSince1970))
        
        self.name = name
        self.originalImage = originalImage
        self.croppedImage = croppedImage
        self.quad = quad
        self.originalImagePath = originalImage.saveToTempDirectory(withName: name + "_original_" + unixTimestamp + ".jpg")
        if let croppedImage = croppedImage {
            self.croppedImagePath = croppedImage.saveToTempDirectory(withName: name + "_crop_" + unixTimestamp + ".jpg")
        }
    }
}

struct DocumentScannerHome: View {
    @State private var selectedImage: UIImage?
    @State private var images: [ScannedImage] = [
//        ScannedImage(originalImage: UIImage(imageLiteralResourceName: "IMG_9133"))
    ]
    @State private var selectedIndex: Int = 0
    @State private var showCamera: Bool = false
    @State private var showImageEditor: Bool = false
    @State private var retakeImage: Bool = false
    @State private var reselectImage: Bool = false
    @State var selectFromGallery: Bool = false
    @State private var showGallery: Bool = false
    @State private var hasSelectedImage: Bool = false
//    var onSaveToPDF: ((URL) -> Void)?
    var onSave: (([String])->Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            // Header Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Preview")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                
                Spacer()
                
                Button("Done") {
                    
                    if let onSave = onSave {
                        onSave(images.map(\.croppedImagePath!))
                    }
                    dismiss()
                }
                    .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                    .font(.subheadline)
                    .background(Color(.sRGB, red: 170/255, green: 196/255, blue: 248/255))
                    .foregroundColor(.black)
                    .cornerRadius(32)
                    .frame(alignment: .trailing)
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(Color.gray.opacity(0.2))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
            
            
            if images.count > 0 {
                // Main Image List
                TabView(selection: $selectedIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index].croppedImage ?? images[index].originalImage ?? UIImage())
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.7)
                            .tag(index)
                    }
                }
                .padding()
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: UIScreen.main.bounds.height * 0.55)
                
                // Page Indicator
                Text("\(selectedIndex + 1)/\(images.count)")
                    .font(.headline)
                    .padding(.top, 4)
                
                // Thumbnail List
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index].croppedImage ?? images[index].originalImage ?? UIImage())
                                .resizable()
                                .scaledToFit()
                                .frame(width: selectedIndex == index ? 48 : 43, height: selectedIndex == index ? 65 : 58)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIndex == index ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedIndex = index
                                    }
                                }
                        }
                        
                        // "+" Button for Adding Images
                        if images.count < 10 {
                            Button(action: {
                                if selectFromGallery {
                                    showGallery = true
                                } else {
                                    showCamera = true
                                }
                            }) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 2)
                                    .frame(width: 43, height: 58)
                                    .overlay(
                                        Text("+")
                                            .font(.title)
                                            .foregroundColor(Color(.sRGB, red: 170/255, green: 196/255, blue: 248/255))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 80)
            }
            Spacer()
            
            // Bottom Tab Bar
            HStack {
                TabButton(icon: "crop.rotate", label: "Crop & Rotate") {
                    showImageEditor = true
                }
                                
                TabButton(icon: selectFromGallery ? "photo.on.rectangle" : "camera", label: selectFromGallery ? "Reselect" : "Retake") {
                    if selectFromGallery {
                        reselectImage = true
                    } else {
                        retakeImage = true
                    }
                }
                                
                TabButton(icon: "trash", label: "Delete") {
                    deleteImageAtIndex(selectedIndex)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.top, 12)
            .background(Color.gray.opacity(0.2))
        }
        .background(.black)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color("Gray"), for: .tabBar)
        // When Camera Opens
        .fullScreenCover(isPresented: $showCamera) {
            let filename = "Page_\(images.count + 1)"
            
            DocumentScannerCameraView(
                imageName: filename,
                onImageCaptured: {
                originalImage, editedImage, quad in
                
                let scannedImage = ScannedImage(
                    name: filename,
                    originalImage: originalImage,
                    croppedImage: editedImage,
                    quad: quad
                )
                self.images.append(scannedImage)
                selectedIndex = images.count - 1
            }, onImageCaptureCancelled: {
                dismissViewIfEmpty()
            })
        }
        // When "Crop & Rotate" is pressed
        .fullScreenCover(isPresented: $showImageEditor) {
            DocumentScannerPreviewView(
                imageName: images[selectedIndex].name,
                image: $images[selectedIndex].originalImage,
                quad: $images[selectedIndex].quad,
                isEditing: true
            ) {
                    name, originalImage, editedImage, quad in
                
                let scannedImage = ScannedImage(
                    name: name,
                    originalImage: originalImage,
                    croppedImage: editedImage,
                    quad: quad
                )
                replaceAtIndex(selectedIndex, newScannedImage: scannedImage)
            }
        }
        // When "Retake" is pressed
        .fullScreenCover(isPresented: $retakeImage) {
            let filename = "Page_\(selectedIndex + 1)"
            
            DocumentScannerCameraView(
                imageName: filename,
                onImageCaptured: {
                originalImage, editedImage, quad in
                
                let scannedImage = ScannedImage(
                    name: filename,
                    originalImage: originalImage,
                    croppedImage: editedImage,
                    quad: quad
                )
                replaceAtIndex(selectedIndex, newScannedImage: scannedImage)
            }, onImageCaptureCancelled: {
                dismissViewIfEmpty()
            })
        }
        // When "Reselect" is pressed
        .fullScreenCover(isPresented: $reselectImage) {
            ImagePickerView(onSelect: {image in
                selectedImage = image
                hasSelectedImage = true
            }, onDismiss: {
                dismissViewIfEmpty()
            })
        }
        // When "Select from Gallery" is pressed
        .fullScreenCover(isPresented: $showGallery) {
            ImagePickerView(onSelect: {image in
                selectedImage = image
                hasSelectedImage = true
            }, onDismiss: {
                dismissViewIfEmpty()
            })
        }
        // After user selects an image from "Gallery" on new or "Reselect"
        .fullScreenCover(isPresented: $hasSelectedImage) {
            let filename = "Page_\(reselectImage ? selectedIndex + 1 : images.count + 1)"
            DocumentScannerPreviewView(
                imageName: filename,
                image: $selectedImage, quad: .constant(nil), isEditing: true, onImageEdited: {
                    name, originalImage, editedImage, quad in
                
                let scannedImage = ScannedImage(
                    name: name,
                    originalImage: originalImage,
                    croppedImage: editedImage,
                    quad: quad
                )
                
                if reselectImage {
                    replaceAtIndex(selectedIndex, newScannedImage: scannedImage)
                } else {
                    self.images.append(scannedImage)
                    selectedIndex = images.count - 1
                }
                self.reselectImage = false
            }, onDismiss: {
                dismissViewIfEmpty()
            })
        }
        .onAppear() {
            if self.images.count == 0 {
                if selectFromGallery {
                    showGallery = true
                } else {
                    showCamera = true
                }
            }
        }
    }
    
    func dismissViewIfEmpty() {
        if images.count == 0 {
            dismiss()
        }
    }
    
    func deleteFileAtPath(_ path: String) {
        let fileURL = URL(fileURLWithPath: path)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print(error)
        }
    }
    
    func deleteImageAtIndex(_ index: Int) {
        let scannedImage = self.images[index]
        if let originalImagePath = scannedImage.originalImagePath {
            deleteFileAtPath(originalImagePath)
        }
        if let croppedImagePath = scannedImage.croppedImagePath {
            deleteFileAtPath(croppedImagePath)
        }
        images.remove(at: index)
        if index == 0 {
            dismissViewIfEmpty()
        } else {
            selectedIndex = index - 1
        }
    }
    
    func replaceAtIndex(_ index: Int, newScannedImage: ScannedImage) {
        let oldScannedImage = self.images[index]
        if let originalImagePath = oldScannedImage.originalImagePath {
            deleteFileAtPath(originalImagePath)
        }
        if let croppedImagePath = oldScannedImage.croppedImagePath {
            deleteFileAtPath(croppedImagePath)
        }
        self.images[selectedIndex] = newScannedImage
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

struct TabButton : View {
    var icon: String
    var label: String
    var action: () -> Void
    
    
    var body : some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .padding(.bottom, 4)
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(.white)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}

struct DocumentScannerHome_Previews: PreviewProvider {
    static var previews: some View {
        DocumentScannerHome()
    }
}
