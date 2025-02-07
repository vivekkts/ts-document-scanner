//
//  View+Extension.swift
//  WeScanSampleProject
//
//  Created by Vivek Kaushal on 2/6/25.
//  Copyright © 2025 WeTransfer. All rights reserved.
//

import SwiftUI

extension View {
    var isPresentedModally: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return false
        }
        return window.rootViewController?.presentedViewController != nil
    }
}
