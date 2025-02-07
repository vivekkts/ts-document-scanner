import Flutter
import UIKit
import SwiftUI
import WeScan

@available(iOS 13.0, *)
public class SwiftDocumentScannerPlugin: NSObject, FlutterPlugin, UIApplicationDelegate {
    var resultChannel: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "document_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>

        if (call.method == "getPictures")
        {
            print("Hello", "getPictures")
            if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
                // let destinationViewController = HomeViewController()
                // destinationViewController.setParams(saveTo: saveTo, canUseGallery: canUseGallery)
                // destinationViewController._result = result
                // viewController.present(destinationViewController,animated: true,completion: nil);
                
                self.resultChannel = result
                
                let documentScannerView = DocumentScannerHome()
                let documentScannerViewController = UIHostingController(rootView: documentScannerView)
                
                documentScannerViewController.rootView.onSave = { [weak self] images in
                    print("IMAGES RECEIVED", images)
                    self?.resultChannel?(images)
                }
                
                documentScannerViewController.modalPresentationStyle = .fullScreen
                viewController.present(documentScannerViewController, animated: true, completion: nil)
            }
        }
        if (call.method == "selectDocuments")
        {
            print("Hello", "selectDocuments")
            if let viewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
                self.resultChannel = result
                
                let documentScannerView = DocumentScannerHome(selectFromGallery: true)
                let documentScannerViewController = UIHostingController(rootView: documentScannerView)
                
                documentScannerViewController.rootView.onSave = { [weak self] images in
                    print("IMAGES RECEIVED", images)
                    self?.resultChannel?(images)
                }
                
                documentScannerViewController.modalPresentationStyle = .fullScreen
                viewController.present(documentScannerViewController, animated: true, completion: nil)
            }
        }
    }
}
