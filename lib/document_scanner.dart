import 'dart:async';

import 'package:document_scanner/src/models/contour.dart';
import 'package:document_scanner/src/models/filter_type.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class DocumentScanner {
  static const MethodChannel _channel =
      MethodChannel('document_scanner');

  /// Call this to start get Picture workflow.
  // static Future<List<String>?> getPictures(
  //     {int noOfPages = 100, bool isGalleryImportAllowed = false}) async {
  //   Map<Permission, PermissionStatus> statuses = await [
  //     Permission.camera,
  //   ].request();
  //   if (statuses.containsValue(PermissionStatus.denied) ||
  //       statuses.containsValue(PermissionStatus.permanentlyDenied)) {
  //     throw Exception("Permission not granted");
  //   }
  //
  //   final List<dynamic>? pictures = await _channel.invokeMethod('getPictures', {
  //     'noOfPages': noOfPages,
  //     'isGalleryImportAllowed': isGalleryImportAllowed
  //   });
  //   return pictures?.map((e) => e as String).toList();
  // }

  static Future<Map<String, dynamic>?> getPictures(
      {int noOfPages = 100, bool isGalleryImportAllowed = false}) async {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
      ].request();
      if (statuses.containsValue(PermissionStatus.denied) ||
          statuses.containsValue(PermissionStatus.permanentlyDenied)) {
        throw Exception("Permission not granted");
      }
    try {
      final result = await _channel.invokeMethod('getPictures', {
        'noOfPages': noOfPages,
        'isGalleryImportAllowed': isGalleryImportAllowed,
      });

      print("resultant $result");

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print("I am inside iOS");

        if (result != null) {
          print("Processing iOS result");
          List<String> images = List<String>.from(result['images'] ?? []);
          String filename = result['name'] ?? '';

          return {
            'croppedImageResults': images,
            'filename': filename,
          };
        }
      }

      if (result != null && result is Map) {
        final croppedImageResults = List<String>.from(result['croppedImageResults'] ?? []);
        final filename = result['filename'] ?? '';

        return {'croppedImageResults': croppedImageResults, 'filename': filename};
      }

      return null;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> selectDocuments(
      {int noOfPages = 100, List<String>? sharedFiles}) async {
    Map<Permission, PermissionStatus> statuses;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      statuses = await [Permission.photos].request();
    } else {
      statuses = await [Permission.mediaLibrary].request();
    }

    if (statuses.containsValue(PermissionStatus.denied) ||
        statuses.containsValue(PermissionStatus.permanentlyDenied)) {
      throw Exception("Permission not granted");
    }
    try {

      final result = await _channel.invokeMethod('selectDocuments', {
        'noOfPages': noOfPages,
        'sharedFiles': sharedFiles
      });
      print("resultant $result");

      // if (defaultTargetPlatform == TargetPlatform.iOS) {
      //   print("i am inside ios");
      //   if (result != null && result is List) {
      //     // Convert the result to a Map<String, dynamic>
      //     return {
      //       'croppedImageResults': result.map((e) => e as String).toList(),
      //       'filename': '', // Add a default filename or modify as needed
      //     };
      //   }
      // }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print("I am inside iOS");

        if (result != null ) {
          // Extract images and name correctly from the Map
          print("i am inside results");
          List<String> images = List<String>.from(result['images'] ?? []);
          String filename = result['name'] ?? '';

          return {
            'croppedImageResults': images,
            'filename': filename, // Use the actual filename from the result
          };
        }
      }
      if (result != null && result is Map) {
        final croppedImageResults = List<String>.from(result['croppedImageResults'] ?? []);
        final filename = result['filename'] ?? '';


        return {'croppedImageResults': croppedImageResults, 'filename': filename};
      }
      return null;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return null;
    }
  }


  static Future<Contour?> findContourPhoto({
    required Uint8List byteData,
    required double minContourArea,
  }) async {
    final contour = await _channel.invokeMapMethod<String, dynamic>(
      'findContourPhoto',
      <String, Object>{
        'byteData': byteData,
        'minContourArea': minContourArea,
      },
    );

    if (contour != null) {
      return Contour.fromMap(contour);
    }

    return null;
  }

  static Future<Uint8List?> adjustingPerspective({
    required Uint8List byteData,
    required Contour contour,
  }) async {
    return _channel.invokeMethod<Uint8List>(
      'adjustingPerspective',
      <String, Object>{
        'byteData': byteData,
        'points': contour.points
            .map(
              (e) => {
                'x': e.x,
                'y': e.y,
              },
            )
            .toList(),
      },
    ).then((value) => value);
  }

  static Future<Uint8List?> applyFilter({
    required Uint8List byteData,
    required FilterType filter,
  }) async {
    return _channel.invokeMethod<Uint8List>(
      'applyFilter',
      <String, Object>{
        'byteData': byteData,
        'filter': filter.value,
      },
    ).then((value) => value);
  }
}

/*
// TODO: Can use this class to return name and pictures instead
// of only pictures based on the following code base example:
// https://api.flutter.dev/flutter/services/MethodChannel/invokeMethod.html 
*/
class DocumentResult {
  DocumentResult(this.name, this.pictures);

  final String name;
  final List<String> pictures;

  static DocumentResult fromJson(Map<String, Object?> json) {
    return DocumentResult(json['name']! as String, json['pictures']! as List<String>);
  }
}
