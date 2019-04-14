//
//  PhotoListViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewController: UIViewController {

    @IBOutlet weak var photoListView: UICollectionView!
    private let coreDataStore = CoreDataStore()
    private var assetEntitys = [AssetEntity]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard success else {
                self?.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }
            print("許可成功")
        }
    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assetEntitys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(indexPath)
    }
}
