import SwiftUI
import WeScan

struct DocumentScannerPreviewView: View {
    var imageName: String = ""
    
    @Binding var image: UIImage?
    @Binding var quad: Quadrilateral?
    
    var isEditing: Bool = false
    var onImageEdited: ((String, UIImage, UIImage, Quadrilateral?) -> Void)?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
        
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Text(imageName)
                            .font(.title3)
                            .foregroundStyle(.white)

                        Button(action: {
                            
                        }) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .offset(y: 4)
                            
                        , alignment: .bottom
                    )
                    .foregroundStyle(.white)
                    
                    EditImageViewControllerWrapper(image: $image, quad: $quad, onCropped: { editedImage, quad in
                        if let originalImage = image, let onImageEdited = onImageEdited {
                            onImageEdited(imageName, originalImage, editedImage, quad)
                        }
                        if isEditing {
                            if let onDismiss = onDismiss {
                                onDismiss()
                            }
                            dismiss()
                        }
                        
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    actionControls(geometry: geometry) {
                        NotificationCenter.default.post(name: .cropImage, object: nil)
                    }
                    Spacer()
                }
                .background(Color.black)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Crop & Rotate")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
    
    private func actionControls(geometry: GeometryProxy, action: @escaping () -> Void) -> some View {
        if #available(iOS 16.0, *) {
            return (
                VStack(alignment: .trailing, spacing: 16) {
                    HStack {
                        ActionButton(icon: "crop", label: "Automatic Crop") {
                            NotificationCenter.default.post(name: .autoCrop, object: nil)
                        }
                        ActionButton(icon: "crop", label: "No Crop") {
                            NotificationCenter.default.post(name: .resetCrop, object: nil)
                        }
                        ActionButton(icon: "arrow.clockwise", label: "Rotate") {
                            NotificationCenter.default.post(name: .rotateImage, object: nil)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .foregroundColor(Color.gray)
                    
                    Button("Apply", action: action)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                        .background(Color(.sRGB, red: 170/255, green: 196/255, blue: 248/255))
                        .foregroundColor(.black)
                        .cornerRadius(32)
                        .frame(alignment: .trailing)
                }
                .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                .background(Color.gray.opacity(0.2))
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 24, bottomLeading: 0, bottomTrailing: 0, topTrailing: 24)))
            )
        } else {
            // Fallback on earlier versions
            return (
                VStack {
                    HStack {
                        ActionButton(icon: "crop", label: "Automatic Crop") {
                            NotificationCenter.default.post(name: .autoCrop, object: nil)
                        }
                        ActionButton(icon: "crop", label: "No Crop") {
                            NotificationCenter.default.post(name: .resetCrop, object: nil)
                        }
                        ActionButton(icon: "arrow.clockwise", label: "Rotate") {
                            NotificationCenter.default.post(name: .rotateImage, object: nil)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .foregroundColor(Color.gray)
                    
                    Button("Apply", action: action)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            )
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        VStack {
            Button(action: action) {
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            Text(label)
                .font(.caption)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}

struct EditImageViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var quad: Quadrilateral?
    var onCropped: (UIImage, Quadrilateral?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onCropped: onCropped)
    }
    
    func makeUIViewController(context: Context) -> WeScan.EditImageViewController {
        let controller = WeScan.EditImageViewController(
            image: image!,
            quad: quad,
            rotateImage: false,
            strokeColor: Color(.white).cgColor
        )
        controller.delegate = context.coordinator
        
        NotificationCenter.default.addObserver(forName: .cropImage, object: nil, queue: .main) { _ in
            controller.cropImage()
        }
        NotificationCenter.default.addObserver(forName: .rotateImage, object: nil, queue: .main) { _ in
            controller.rotateImage()
        }
        NotificationCenter.default.addObserver(forName: .resetCrop, object: nil, queue: .main) { _ in
            controller.resetQuadToDefault()
        }
        NotificationCenter.default.addObserver(forName: .autoCrop, object: nil, queue: .main) { _ in
            controller.detectQuad()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: WeScan.EditImageViewController, context: Context) {}
    
    class Coordinator: NSObject, EditImageViewDelegate {
        var parent: EditImageViewControllerWrapper
        var onCropped: (UIImage, Quadrilateral?) -> Void
        
        init(_ parent: EditImageViewControllerWrapper, onCropped: @escaping (UIImage, Quadrilateral?) -> Void) {
            self.parent = parent
            self.onCropped = onCropped
        }
        
        func cropped(image: UIImage, quad: Quadrilateral?) {
            onCropped(image, quad)
        }
    }
}

extension Notification.Name {
    static let cropImage = Notification.Name("cropImage")
    static let rotateImage = Notification.Name("rotateImage")
    static let resetCrop = Notification.Name("resetCrop")
    static let autoCrop = Notification.Name("autoCrop")
}

//struct DocumentScannerPreviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        DocumentScannerPreviewView(image: UIImage(named: "IMG_9133") ?? UIImage(), croppedImage: nil, quad: nil)
//    }
//}
