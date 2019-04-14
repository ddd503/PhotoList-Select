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

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if !editing {
            deselectCell()
        }
    }

    private func setup() {
        photoListView.dataSource = self
        photoListView.delegate = self
        photoListView.register(PhotoListViewCollectionViewCell.nib(),
                               forCellWithReuseIdentifier: PhotoListViewCollectionViewCell.identifier)

        navigationItem.rightBarButtonItem = editButtonItem

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }

            PhotoLibraryDataStore.requestAssets().forEach {
                self.coreDataStore.insertAsset(asset: $0)
            }

            self.coreDataStore.fetchAllAssetEntity(completion: { (result) in
                switch result {
                case .success(let assetEntitys):
                    self.assetEntitys = assetEntitys
                    self.photoListView.reloadData()
                case .failure(let error):
                    self.showAttentionAlert(title: "取得失敗", message: error.localizedDescription)
                }
            })

        }
    }

    private func deselectCell() {
        (0...assetEntitys.count).forEach { [weak self] in
            if let cell = self?.photoListView.cellForItem(at: IndexPath(item: $0, section: 0)) as? PhotoListViewCollectionViewCell {
                cell.resetViewStatus()
            }
        }

    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // ここをそのままfetchControllerにする
        return assetEntitys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }
        cell.setImage(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.row].localIdentifier))
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell, isEditing {
            selectCell.updateViewStatus()
        }
    }
}
