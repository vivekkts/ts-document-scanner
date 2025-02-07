//
//  UIImage+Extension.swift
//  WeScanSampleProject
//
//  Created by Vivek Kaushal on 2/6/25.
//  Copyright © 2025 WeTransfer. All rights reserved.
//

import UIKit

extension UIImage {
    func saveToTempDirectory(withName name: String) -> String? {
        let tempDirectoryURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let tempDirectoryURL = tempDirectoryURLs.first else { return nil }
        let fileURL = tempDirectoryURL.appendingPathComponent(name)
        do {
            try pngData()?.write(to: fileURL)
        } catch {
            print(error)
        }
        
        return fileURL.path()
    }
}
