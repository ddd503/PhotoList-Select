//
//  PhotoLibraryDataStore.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import Photos

final class PhotoLibraryDataStore {

    static func requestAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets = [PHAsset]()
        fetchResult.enumerateObjects(options: NSEnumerationOptions.concurrent) { (asset, index, _) in
            assets.append(asset)
        }
        return assets
    }

    static func canAccess() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }

    static func needsToRequestAccess() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .notDetermined
    }

    static func requestAuthorization(completion handler: @escaping (Bool) -> Void) {
        guard PhotoLibraryDataStore.needsToRequestAccess() else {
            handler(PhotoLibraryDataStore.canAccess())
            return
        }
        PHPhotoLibrary.requestAuthorization { _ in
            handler(PhotoLibraryDataStore.canAccess())
        }
    }

}
