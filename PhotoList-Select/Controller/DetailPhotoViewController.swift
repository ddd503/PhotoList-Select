//
//  DetailPhotoViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/20.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit
import Photos

final class DetailPhotoViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    fileprivate var asset: PHAsset?

    class func make(asset: PHAsset?) -> DetailPhotoViewController? {
        let sb = UIStoryboard(name: "PhotoListViewController", bundle: .main)
        let vc = sb.instantiateViewController(withIdentifier: String(describing: DetailPhotoViewController.self)) as? DetailPhotoViewController
        vc?.asset = asset
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImage()
    }

    private func setupImage() {
        if let asset = asset {
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: CGSize(width: imageView.bounds.size.width, height: imageView.bounds.size.height),
                                                  contentMode: .aspectFill,
                                                  options: nil) { [weak self] (image, info) in
                                                    self?.imageView.image = image
            }
        } else {
            imageView.image = UIImage(named: "no_image")
        }
    }
}
