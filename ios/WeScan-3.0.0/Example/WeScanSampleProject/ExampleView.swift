import SwiftUI

struct HomeView: View {
    @State private var showImageList = false
    
    var body: some View {
        VStack {
            Button("Open Image List") {
                showImageList = true
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showImageList) {
            ImageListView()
        }
    }
}

struct ImageListView: View {
    @State private var images: [UIImage] = []
    @State private var showImageSelector = false
    
    var body: some View {
        NavigationView {
            VStack {
                List(images, id: \ .self) { image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                }
                
                Button("+") {
                    showImageSelector = true
                }
                .padding()
            }
            .navigationTitle("Selected Images")
            .fullScreenCover(isPresented: $showImageSelector) {
                ImageSelectorView(onImageSelected: { selectedImage in
                    showImageSelector = false
                    showImageEditor(image: selectedImage)
                })
            }
        }
    }
    
    func showImageEditor(image: UIImage) {
        let editorView = ExampleImageEditorView(image: image) { editedImage in
            images.append(editedImage)
        }
        
        let controller = UIHostingController(rootView: editorView)
        UIApplication.shared.windows.first?.rootViewController?.present(controller, animated: true)
    }
}

struct ImageSelectorView: View {
    let images = [UIImage(systemName: "photo")!, UIImage(systemName: "photo.fill")!, UIImage(systemName: "star")!]
    var onImageSelected: (UIImage) -> Void
    
    var body: some View {
        VStack {
            ForEach(images, id: \ .self) { image in
                Button(action: {
                    onImageSelected(image)
                }) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .padding()
                }
            }
        }
        .navigationTitle("Select an Image")
    }
}

struct ExampleImageEditorView: View {
    let image: UIImage
    var onSave: (UIImage) -> Void
    
    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 300)
                .padding()
            
            Button("Save") {
                onSave(image)
                dismissView()
            }
            .padding()
        }
    }
    
    func dismissView() {
        UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true)
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

