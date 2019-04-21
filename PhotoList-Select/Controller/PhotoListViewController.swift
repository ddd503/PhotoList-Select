//
//  PhotoListViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewController: UIViewController {

    @IBOutlet weak private var photoListView: UICollectionView!
    private let coreDataStore = CoreDataStore()
    private var assetEntitys = [AssetEntity]()
    // 選択されているセルを持つ
    private var selectedItems = [String: IndexPath]()
    private var lastPanIndexPath: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()

        //        let documentDirPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        //        print(documentDirPath)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if !editing {
            deselectCell()
        }
        setTrashButtonIsHidden(!editing)
    }

    private func setup() {
        setupPhotoListView()
        setupTrashButton()
        setupPanGesture()

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }
            // ローカルから取得して永続化
            self.prepareAssetEntitys()
            // 永続化した写真(AssetEntity)を全てfetch
            self.requestAssetEntitys()
        }
    }

    private func setupPhotoListView() {
        photoListView.dataSource = self
        photoListView.delegate = self
        photoListView.register(PhotoListViewCollectionViewCell.nib(),
                               forCellWithReuseIdentifier: PhotoListViewCollectionViewCell.identifier)
        photoListView.allowsMultipleSelection = true
    }

    private func setupTrashButton() {
        navigationItem.rightBarButtonItem = editButtonItem
        let trushButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapTrashButton))
        navigationItem.leftBarButtonItem = trushButton
        setTrashButtonIsHidden(true)
    }

    private func setupPanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(toSelectCells:)))
        photoListView.addGestureRecognizer(gesture)
    }

    private func prepareAssetEntitys() {
        PhotoLibraryDataStore.requestAssets().forEach {
            self.coreDataStore.insertAssetEntity(with: $0)
        }
    }

    private func requestAssetEntitys() {
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

    private func deselectCell() {
        (0...assetEntitys.count).forEach { [weak self] in
            let indexPath = IndexPath(item: $0, section: 0)
            self?.photoListView.deselectItem(at: indexPath, animated: false)
            self?.selectedItems = [:]
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

    private func hiddenSelectedItems() {
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
            self?.showFinishLabel()
        }
    }

    @objc private func didTapTrashButton() {
        // 選択数が0ならreturn
        guard !selectedItems.isEmpty else { return }
        hiddenSelectedItems()
    }

    // 任意のセルを選択した状態からパンをスタートしたか
    private var isStartHasCheckBoxCell = false

    @objc private func didPan(toSelectCells panGesture: UIPanGestureRecognizer) {
        guard isEditing else { return }

        switch panGesture.state {
        case .began:
            photoListView.isUserInteractionEnabled = false
            photoListView.isScrollEnabled = false
            let location = panGesture.location(in: photoListView)
            guard let currentIndexPath = photoListView.indexPathForItem(at: location),
                let currentAssetLocalId = assetEntitys[currentIndexPath.item].localIdentifier else { return }
            // 選択 or 非選択　どっちスタートか
            isStartHasCheckBoxCell = selectedItems[currentAssetLocalId] != nil

        case .changed:
            let location = panGesture.location(in: photoListView)

            guard let currentIndexPath = photoListView.indexPathForItem(at: location),
                let currentAssetLocalId = assetEntitys[currentIndexPath.item].localIdentifier,
                lastPanIndexPath != currentIndexPath else { return }

            // 指を置いているセルが選択中か？
            let isSelectCurrentAsset = selectedItems[currentAssetLocalId] != nil
            // 前に触っていたセルの選択状態を管理
            var isSelectPreviousAsset: Bool?

            print("前に触っていたセルの処理")
            // 前に触っていたセルの処理
            if let lastPanIndexPath = lastPanIndexPath,
                let previousAssetLocalId = assetEntitys[lastPanIndexPath.item].localIdentifier {
                // 前に触ったセルが選択中か？
                let isSelect = selectedItems[previousAssetLocalId] != nil
                if isSelect {
                    // 前のセルは選択中
                    if isSelectCurrentAsset {
                        selectedItems.removeValue(forKey: previousAssetLocalId)
                        photoListView.deselectItem(at: lastPanIndexPath, animated: false)
                        isSelectPreviousAsset = false
                        print("deselect")
                    } else {
                        selectedItems[previousAssetLocalId] = lastPanIndexPath
                        // TODO: - 複数セル選択時に挙動を確認
                        photoListView.selectItem(at: lastPanIndexPath, animated: false, scrollPosition: .bottom)
                        isSelectPreviousAsset = true
                        print("select")
                    }
                } else {
                    // 前のセルは非選択中
                    if isSelectCurrentAsset {
                        selectedItems.removeValue(forKey: previousAssetLocalId)
                        photoListView.deselectItem(at: lastPanIndexPath, animated: false)
                        isSelectPreviousAsset = false
                        print("deselect")
                    } else {
                        selectedItems[previousAssetLocalId] = lastPanIndexPath
                        // TODO: - 複数セル選択時に挙動を確認
                        photoListView.selectItem(at: lastPanIndexPath, animated: false, scrollPosition: .bottom)
                        isSelectPreviousAsset = true
                        print("select")
                    }
                }
            }

            print("指を置いているセルの処理")
            // 指を置いているセルの処理
            if let isSelectPreviousAsset = isSelectPreviousAsset {
                if isSelectPreviousAsset {
                    if isSelectCurrentAsset {
                        selectedItems.removeValue(forKey: currentAssetLocalId)
                        photoListView.deselectItem(at: currentIndexPath, animated: false)
                        print("deselect")

                    } else {
                        selectedItems[currentAssetLocalId] = currentIndexPath
                        // TODO: - 複数セル選択時に挙動を確認
                        photoListView.selectItem(at: currentIndexPath, animated: false, scrollPosition: .bottom)
                        print("select")
                    }
                } else {
                    if isStartHasCheckBoxCell {
                        if isSelectCurrentAsset {
                            selectedItems.removeValue(forKey: currentAssetLocalId)
                            photoListView.deselectItem(at: currentIndexPath, animated: false)
                            print("deselect")
                        } else {
                            selectedItems[currentAssetLocalId] = currentIndexPath
                            // TODO: - 複数セル選択時に挙動を確認
                            photoListView.selectItem(at: currentIndexPath, animated: false, scrollPosition: .bottom)
                            print("select")
                        }
                    } else {
                        if isSelectCurrentAsset {
                            selectedItems[currentAssetLocalId] = currentIndexPath
                            // TODO: - 複数セル選択時に挙動を確認
                            photoListView.selectItem(at: currentIndexPath, animated: false, scrollPosition: .bottom)
                            print("select")
                        } else {
                            selectedItems.removeValue(forKey: currentAssetLocalId)
                            photoListView.deselectItem(at: currentIndexPath, animated: false)
                            print("deselect")
                        }
                    }
                }
            } else {
                // ファーストタッチ時
                if isSelectCurrentAsset {
                    selectedItems.removeValue(forKey: currentAssetLocalId)
                    photoListView.deselectItem(at: currentIndexPath, animated: false)
                    print("deselect")
                } else {
                    selectedItems[currentAssetLocalId] = currentIndexPath
                    // TODO: - 複数セル選択時に挙動を確認
                    photoListView.selectItem(at: currentIndexPath, animated: false, scrollPosition: .bottom)
                    print("select")
                }
            }

            self.lastPanIndexPath = currentIndexPath
        case .ended:
            photoListView.isScrollEnabled = true
            photoListView.isUserInteractionEnabled = true
            lastPanIndexPath = nil
        default: break
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
        if isEditing {
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems[localId] = indexPath
                lastPanIndexPath = indexPath
            }
        } else {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard let detailVC = DetailPhotoViewController.make(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.item].localIdentifier)) else { return }
            navigationController?.pushViewController(detailVC, animated: true)
            collectionView.deselectItem(at: indexPath, animated: false)
        }

    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard isEditing else { return }
        if let localId = assetEntitys[indexPath.item].localIdentifier {
            selectedItems.removeValue(forKey: localId)
            lastPanIndexPath = indexPath
        }
    }
}
