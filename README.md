# cunning_document_scanner

A state of the art document scanner with automatic cropping function.

<img src="https://user-images.githubusercontent.com/1488063/167291601-c64db2d5-78ab-4781-bc7a-afe7eb93e083.png" height ="400"  alt=""/>
<img src="https://user-images.githubusercontent.com/1488063/167291821-3b66d0bb-b636-4911-a572-d2368dc95012.jpeg" height ="400"  alt=""/>
<img src="https://user-images.githubusercontent.com/1488063/167291827-fa0ae804-1b81-4ef4-8607-3b212c3ab1c0.jpeg" height ="400"  alt=""/>


## Getting Started

Handle camera access permission

### **IOS**

1. Add a String property to the app's Info.plist file with the key NSCameraUsageDescription and the value as the description for why your app needs camera access.

   <key>NSCameraUsageDescription</key>
   <string>Camera Permission Description</string>

2. The <kbd>permission_handler</kbd> dependency used by cunning_document_scanner use [macros](https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_apple/ios/Classes/PermissionHandlerEnums.h) to control whether a permission is enabled. Add the following to your `Podfile` file:

   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       ... # Here are some configurations automatically generated by flutter

       # Start of the permission_handler configuration
       target.build_configurations.each do |config|

         # You can enable the permissions needed here. For example to enable camera
         # permission, just remove the `#` character in front so it looks like this:
         #
         # ## dart: PermissionGroup.camera
         # 'PERMISSION_CAMERA=1'
         #
         #  Preprocessor definitions can be found at: https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_apple/ios/Classes/PermissionHandlerEnums.h
         config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
           '$(inherited)',

           ## dart: PermissionGroup.camera
           'PERMISSION_CAMERA=1',
         ]

       end
       # End of the permission_handler configuration
     end
   end
   ```

### **Android**

minSdkVersion should be at least 21


## How to use ?

The easiest way to get a list of images is:

```
    final imagesPath = await CunningDocumentScanner.getPictures()
```

Additionally you can limit the number of pages as follows:

```
    final imagesPath = await CunningDocumentScanner.getPictures(noOfPages: 1)
```

This would limit the number of pages to one.

## Contributing

### Step 1

- Fork this project's repo :

### Step 2

-  Create a new pull request.



## License
This project is licensed under the MIT License - see the LICENSE.md file for details
