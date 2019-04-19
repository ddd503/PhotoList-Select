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
    // 選択されているセルを持つ
    private var selectedItems = [String: IndexPath]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if !editing {
            deselectCell()
        }
        setTrashButtonIsHidden(!editing)
    }

    private func setup() {
        photoListView.dataSource = self
        photoListView.delegate = self
        photoListView.register(PhotoListViewCollectionViewCell.nib(),
                               forCellWithReuseIdentifier: PhotoListViewCollectionViewCell.identifier)
        photoListView.allowsMultipleSelection = true

        navigationItem.rightBarButtonItem = editButtonItem
        let trushButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapTrashButton))
        navigationItem.leftBarButtonItem = trushButton
        setTrashButtonIsHidden(true)

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }

            PhotoLibraryDataStore.requestAssets().forEach {
                self.coreDataStore.insertAssetEntity(with: $0)
            }

            self.coreDataStore.fetchAllAssetEntity(completion: { [weak self] (result) in
                switch result {
                case .success(let assetEntitys):
                    self?.assetEntitys = assetEntitys
                    self?.photoListView.reloadData()
                case .failure(let error):
                    self?.showAttentionAlert(title: "取得失敗", message: error.localizedDescription)
                }
            })

        }
    }

    private func deselectCell() {
        (0...assetEntitys.count).forEach { [weak self] in
            let indexPath = IndexPath(item: $0, section: 0)
            if let cell = self?.photoListView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
                self?.photoListView.deselectItem(at: indexPath, animated: true)
                cell.updateViewStatus(isSelect: false)
                self?.selectedItems = [:]
            }
        }
    }

    private func setTrashButtonIsHidden(_ isHidden: Bool) {
        if isHidden {
            navigationItem.leftBarButtonItem?.isEnabled = false
            navigationItem.leftBarButtonItem?.tintColor = .clear
        } else {
            navigationItem.leftBarButtonItem?.isEnabled = true
            navigationItem.leftBarButtonItem?.tintColor = nil
        }
    }

    @objc private func didTapTrashButton() {
        // 選択数が0ならreturn
        guard !selectedItems.isEmpty else { return }

        // DB側の値を更新
        selectedItems.forEach {
            coreDataStore.fetchAsset(by: $0.key, completion: { [weak self] (result) in
                switch result {
                case .success(let assetEntity):
                    assetEntity.isHidden = true
                    self?.coreDataStore.saveContext(assetEntity.managedObjectContext)
                case .failure(let nserror):
                    print("削除更新失敗")
                    print(nserror.localizedDescription)
                }
            })
        }

        // View側の更新（DB側の更新は待たない）
        let deleteItemLocalIds = selectedItems.map { $0.key }
        assetEntitys = assetEntitys.compactMap {
            if let localId = $0.localIdentifier, !deleteItemLocalIds.contains(localId) {
                return $0
            } else {
                return nil
            }
        }

        photoListView.performBatchUpdates({
            photoListView.deleteItems(at: selectedItems.map { $0.value })
        }) { [weak self] (_) in
            self?.selectedItems = [:]
        }
    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: - セクション分けするときはここでfetchControllerをみる
        return assetEntitys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }

        cell.setImage(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.item].localIdentifier))
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: true)
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems[localId] = indexPath
            }
        }
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: false)
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems.removeValue(forKey: localId)
            }
        }
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
}
