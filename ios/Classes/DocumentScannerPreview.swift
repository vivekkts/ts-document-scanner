import SwiftUI
import WeScan

struct DocumentScannerPreviewView: View {
    @Binding var image: UIImage?
    @Binding var quad: Quadrilateral?
    @State private var hasProcessedImage: Bool = false
    
    var isEditing: Bool = false
    var onImageEdited: ((UIImage, UIImage, Quadrilateral?) -> Void)?
    var onDismiss: (() -> Void)?
    @State private var showAlert = false
    @State private var isApplyButtonDisabled: Bool = false
    
    @Environment(\.dismiss) private var dismiss
        
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    EditImageViewControllerWrapper(image: $image, quad: $quad, onCropped: { editedImage, quad in
                        guard !hasProcessedImage else { return }
                        print("inside preview")
                        hasProcessedImage = true //
                        if let originalImage = image, let onImageEdited = onImageEdited {
                            onImageEdited(originalImage, editedImage, quad)
                        }
                        if isEditing {
//                            if let onDismiss = onDismiss {
//                                onDismiss()
//                            }
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
                            showAlert = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }.alert("Discard Documents?", isPresented: $showAlert) {
                                          Button("Keep editing", role: .cancel) { } // Do nothing on cancel
                                          Button("Discard", role: .destructive) {
                                          onDismiss?() // Call the onDismiss handler

                                              dismiss() // Dismiss the view if user confirms
                                          }
                                      } message: {
                                          Text("If you leave now, Your progress will be lost.")
                                      }
                }
                
//                ToolbarItem(placement: .principal) {
//                    Text("Crop & Rotate")
//                        .font(.title2)
//                        .foregroundStyle(.white)
//                }
ToolbarItem(placement: .principal) {
    Text("Crop & Rotate")
        .font(.title2)
        .foregroundColor(.white)
        .minimumScaleFactor(0.5) // Shrinks text if space is limited
        .lineLimit(1) // Ensures the text stays on one line
}
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear{
          hasProcessedImage = false
          isApplyButtonDisabled = false
        }
    }

    private func actionControls(geometry: GeometryProxy, action: @escaping () -> Void) -> some View {
        if #available(iOS 16.0, *) {
        print("greater then 16.0")
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

                    Button("Apply", action: {
                     isApplyButtonDisabled = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            action()

                            // Update the UI on the main thread (if needed)
                            DispatchQueue.main.async {
                                // Perform any UI updates here
                            }
                        }})
                        .disabled(isApplyButtonDisabled)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                        .background(isApplyButtonDisabled ? Color.gray : Color(.sRGB, red: 170/255, green: 196/255, blue: 248/255))
                        .foregroundColor(.black)
                        .cornerRadius(32)
                        .frame(alignment: .trailing)
                }
                .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                .background(Color.gray.opacity(0.2))
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 24, bottomLeading: 0, bottomTrailing: 0, topTrailing: 24)))
            )
        } else {
        print("lessa than 16.0")
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

                    Button("Apply", action:  {
                                                                 isApplyButtonDisabled = true
                                                                     DispatchQueue.global(qos: .userInitiated).async {
                                                                         action()

                                                                         // Update the UI on the main thread (if needed)
                                                                         DispatchQueue.main.async {
                                                                             // Perform any UI updates here
                                                                         }
                                                                     }})
                     .disabled(isApplyButtonDisabled)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                        .background(isApplyButtonDisabled ? Color.gray : Color.blue) //
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
//        if coordinator == nil {
//                   coordinator = Coordinator(self, onCropped: onCropped)
//                   print("New Coordinator created")
//               } else {
//                   print("Reusing existing Coordinator")
//               }
//               return coordinator!
    }


    func makeUIViewController(context: Context) -> WeScan.EditImageViewController {

        let controller = WeScan.EditImageViewController(
            image: image!,
            quad: quad,
            rotateImage: false,
            strokeColor: Color(.white).cgColor
        )
        controller.delegate = context.coordinator
         context.coordinator.controller = controller //
          NotificationCenter.default.removeObserver(context.coordinator)

  NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(context.coordinator.handleCrop),
        name: .cropImage,
        object: nil
    )

    NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(context.coordinator.handleRotate),
        name: .rotateImage,
        object: nil
    )

    NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(context.coordinator.handleReset),
        name: .resetCrop,
        object: nil
    )

    NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(context.coordinator.handleAutoCrop),
        name: .autoCrop,
        object: nil
    )


        return controller
    }

    func updateUIViewController(_ uiViewController: WeScan.EditImageViewController, context: Context) {}

    class Coordinator: NSObject, EditImageViewDelegate {
        var parent: EditImageViewControllerWrapper
        var onCropped: (UIImage, Quadrilateral?) -> Void
        weak var controller: EditImageViewController?
        private var hasPrimed = false

//        init(_ parent: EditImageViewControllerWrapper, onCropped: @escaping (UIImage, Quadrilateral?) -> Void) {
//            self.parent = parent
//            self.onCropped = onCropped
//        }
init(_ parent: EditImageViewControllerWrapper, onCropped: @escaping (UIImage, Quadrilateral?) -> Void) {
            self.parent = parent
            self.onCropped = onCropped
            super.init()




            // Register observers in the init method
//            NotificationCenter.default.addObserver(
//                forName: .cropImage,
//                object: nil,
//                queue: .main,
//                using: { [weak self] _ in
//                    print("cropimage")
//
//                    self?.controller?.cropImage()
//                }
//            )
//            NotificationCenter.default.addObserver(
//                forName: .rotateImage,
//                object: nil,
//                queue: .main,
//                using: { [weak self] _ in
//                    print("rotateimage")
//                    self?.controller?.rotateImage()
//                }
//            )
//            NotificationCenter.default.addObserver(
//                forName: .resetCrop,
//                object: nil,
//                queue: .main,
//                using: { [weak self] _ in
//                    print("resetquad")
//                    self?.controller?.resetQuadToDefault()
//                }
//            )
//            NotificationCenter.default.addObserver(
//                forName: .autoCrop,
//                object: nil,
//                queue: .main,
//                using: { [weak self] _ in
//                    print("autocrop")
//                    self?.controller?.detectQuad()
//                }
//            )
        }

       @objc func handleCrop() {
           DispatchQueue.main.async {
               print("cropimage")
               self.controller?.cropImage()
           }
       }

       @objc func handleRotate() {
           DispatchQueue.main.async {
                print("rotateimage - controller: \(String(describing: self.controller))")
//              // self.controller?.rotateImage()
//               self.controller?.rotateImage()
//               self.controller?.rotateImage()

print(self.hasPrimed)
  if !self.hasPrimed {
            self.hasPrimed = true
            self.controller?.rotateImage()
            self.controller?.rotateImage() // cancel out the first one, just to prime
            return
        }

        self.controller?.rotateImage()
           }
       }

       @objc func handleReset() {
           DispatchQueue.main.async {
               print("resetquad")
               self.controller?.resetQuadToDefault()
           }
       }

       @objc func handleAutoCrop() {
           DispatchQueue.main.async {
               print("autocrop")
               self.controller?.detectQuad()
           }
       }


//        deinit {
//            // Remove observers when the Coordinator is deallocated
//            NotificationCenter.default.removeObserver(self, name: .cropImage, object: nil)
//            NotificationCenter.default.removeObserver(self, name: .rotateImage, object: nil)
//            NotificationCenter.default.removeObserver(self, name: .resetCrop, object: nil)
//            NotificationCenter.default.removeObserver(self, name: .autoCrop, object: nil)
//            print("deinitialsied preveiew screen")
//        }

        func cropped(image: UIImage, quad: Quadrilateral?) {
            onCropped(image, quad)
        }
//        deinit {
//        print("deinit")
//                NotificationCenter.default.removeObserver(self, name: .cropImage, object: nil)
//                NotificationCenter.default.removeObserver(self, name: .rotateImage, object: nil)
//                NotificationCenter.default.removeObserver(self, name: .resetCrop, object: nil)
//                NotificationCenter.default.removeObserver(self, name: .autoCrop, object: nil)
//            }
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
