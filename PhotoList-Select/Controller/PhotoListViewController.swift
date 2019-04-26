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
    // 任意のセルを選択した状態からパンをスタートしたか
    private var isStartHasCheckBoxCell = false

    // MARK: Life Cycle
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

    // MARK: Setup
    private func setup() {
        setupPhotoListView()
        setupNavigationBarButtonItem()
        setupPanGesture()

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }
            // ローカルから取得して永続化
            self.prepareAssetEntitys()
            // 永続化した写真(AssetEntity)をfetch
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

    private func setupNavigationBarButtonItem() {
        let resetButtonItem = UIBarButtonItem(title: "戻す", style: .plain, target: self, action: #selector(didTapResetButton))
        navigationItem.rightBarButtonItems = [editButtonItem, resetButtonItem]

        let trushButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapTrashButton))
        navigationItem.leftBarButtonItem = trushButtonItem
        setTrashButtonIsHidden(true)
    }

    private func setupPanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(toSelectCells:)))
        view.addGestureRecognizer(gesture)
    }

    private func prepareAssetEntitys() {
        PhotoLibraryDataStore.requestAssets().forEach {
            coreDataStore.insertAssetEntity(with: $0)
        }
    }

    // MARK: Private
    private func requestAssetEntitys() {
        self.coreDataStore.fetchAllIsNotHiddenAssetEntity(completion: { [weak self] (result) in
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
        (0..<assetEntitys.count).forEach { [weak self] in
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

        // 消す際に選択状態を戻す
        selectedItems.forEach { photoListView.deselectItem(at: $0.value, animated: false) }
        
        photoListView.performBatchUpdates({
            photoListView.deleteItems(at: selectedItems.map { $0.value })
        }) { [weak self] (_) in
            guard let self = self else { return }
            self.selectedItems = [:]
            self.showFinishLabel()
        }
    }

    private func switchPhotoListIsScrollEnabled(by fingerPosition: CGPoint) {
        let isScrollEnabled =
            (photoListView.bounds.size.height * 0.2 > fingerPosition.y) ||
            (photoListView.bounds.size.height * 0.8 < fingerPosition.y)
        photoListView.isUserInteractionEnabled = isScrollEnabled
        photoListView.isScrollEnabled = isScrollEnabled
    }

    private func showAllItems(action: UIAlertAction) {
        coreDataStore.fetchAllAssetEntity { [weak self] (result) in
            switch result {
            case .success(let assetEntitys):
                self?.assetEntitys = assetEntitys
                DispatchQueue.main.async {
                    self?.photoListView.reloadData()
                }
            case .failure(let nserror):
                print("元に戻す失敗")
                print(nserror.localizedDescription)
                self?.showAttentionAlert(title: "失敗", message: "画像の復元に失敗しました。")
            }
        }
    }

    @objc private func didTapTrashButton() {
        // 選択数が0ならreturn
        guard !selectedItems.isEmpty else { return }
        hiddenSelectedItems()
    }

    @objc private func didTapResetButton() {
        showReturnConfirmationAlert(message: "削除した写真を復元します。よろしいですか？", actionHandler: showAllItems)
    }

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
            switchPhotoListIsScrollEnabled(by: panGesture.location(in: view))

            let location = panGesture.location(in: photoListView)

            guard let currentIndexPath = photoListView.indexPathForItem(at: location),
                let currentAssetLocalId = assetEntitys[currentIndexPath.item].localIdentifier,
                lastPanIndexPath != currentIndexPath else { return }

            // 指を置いているセルが選択中か？
            let isSelectCurrentAsset = selectedItems[currentAssetLocalId] != nil
            // 前に触っていたセルの選択状態を管理
            var isSelectPreviousAsset: Bool?

            // 前に触っていたセルの処理
            handleSwipeSlectForPrevious(isSelectPreviousAsset: &isSelectPreviousAsset,
                                        isSelectCurrentAsset: isSelectCurrentAsset,
                                        lastPanIndexPath: lastPanIndexPath)

            // 指を置いているセルの処理
            // nilの場合は同じセル内の指移動とみる（初回のみで次回は頭でguardしている）
            let lastPanIndexPath = self.lastPanIndexPath ?? currentIndexPath

            if (lastPanIndexPath.item == currentIndexPath.item) {
                // 同じIndexPath内の移動
                handleSwipeSelectForCurrent(isSelectPreviousAsset: isSelectPreviousAsset,
                                            isSelectCurrentAsset: isSelectCurrentAsset,
                                            item: lastPanIndexPath.item)
            } else if (currentIndexPath.item > lastPanIndexPath.item) {
                // 昇順の移動（lastPanIndexPathは前の処理で別途選択されるから1足す）
                (lastPanIndexPath.item + 1..<currentIndexPath.item + 1).forEach {
                    handleSwipeSelectForCurrent(isSelectPreviousAsset: isSelectPreviousAsset,
                                                isSelectCurrentAsset: isSelectCurrentAsset,
                                                item: $0)
                }
            } else {
                // 降順の移動（降順で欲しいからreversed）
                (currentIndexPath.item..<lastPanIndexPath.item).reversed().forEach {
                    handleSwipeSelectForCurrent(isSelectPreviousAsset: isSelectPreviousAsset,
                                                isSelectCurrentAsset: isSelectCurrentAsset,
                                                item: $0)
                }
            }

            // 次の選択移動のために値を更新
            self.lastPanIndexPath = currentIndexPath

        case .ended:
            photoListView.isScrollEnabled = true
            photoListView.isUserInteractionEnabled = true
            lastPanIndexPath = nil
        default: break
        }
    }

    private func handleSwipeSlectForPrevious(isSelectPreviousAsset: inout Bool?,
                                             isSelectCurrentAsset: Bool,
                                             lastPanIndexPath: IndexPath?) {
        guard let lastPanIndexPath = lastPanIndexPath,
            let assetLocalId = assetEntitys[lastPanIndexPath.item].localIdentifier else { return }

        isSelectPreviousAsset = selectedItems[assetLocalId] != nil

        switch (isSelectPreviousAsset, isSelectCurrentAsset) {
        case (true, false), (false, false):
            selectedItems[assetLocalId] = lastPanIndexPath
            photoListView.selectItem(at: lastPanIndexPath, animated: false, scrollPosition: .centeredHorizontally)
            isSelectPreviousAsset = true
        case (true, true), (false, true):
            selectedItems.removeValue(forKey: assetLocalId)
            photoListView.deselectItem(at: lastPanIndexPath, animated: false)
            isSelectPreviousAsset = false
        default:
            print("isSelectPreviousAssetがnil")
        }

    }

    private func handleSwipeSelectForCurrent(isSelectPreviousAsset: Bool?,
                                             isSelectCurrentAsset: Bool,
                                             item: Int) {
        guard let assetLocalId = assetEntitys[item].localIdentifier else { return }

        let currentIndexPath = IndexPath(item: item, section: 0)

        switch (isSelectPreviousAsset, isSelectCurrentAsset, isStartHasCheckBoxCell) {
        case (nil, false, _),
             (true, false, _),
             (false, false, true),
             (false, false, true):
            selectedItems[assetLocalId] = currentIndexPath
            photoListView.selectItem(at: currentIndexPath, animated: false, scrollPosition: .centeredHorizontally)
        case (nil, true, _),
             (true, true, _),
             (false, true, true),
             (false, true, true),
             (false, false, false),
             (false, true, false):
            selectedItems.removeValue(forKey: assetLocalId)
            photoListView.deselectItem(at: currentIndexPath, animated: false)
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
