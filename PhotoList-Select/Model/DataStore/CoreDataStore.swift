//
//  CoreDataStore.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import CoreData
import Photos

final class CoreDataStore {

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "PhotoList_Select")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func saveContext(_ context: NSManagedObjectContext? = nil) {
        let context = context ?? persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func insertAssetEntity(with asset: PHAsset) {
        guard isNotExist(localId: asset.localIdentifier) else { return }

        let context = persistentContainer.viewContext
        guard let insertObject = NSEntityDescription.insertNewObject(forEntityName: "AssetEntity", into: context) as? AssetEntity else {
            print("保存失敗")
            return
        }
        insertObject.localIdentifier = asset.localIdentifier
        insertObject.creationDate = asset.creationDate
        insertObject.isHidden = false
        saveContext(context)
    }

    func fetchAllAssetEntity(completion: @escaping (Result<[AssetEntity], NSError>) -> ()) {
        let context = persistentContainer.viewContext

        context.perform {
            let fetchRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
            // isHiddenがtrueでないもののみ取得（削除していないもの）
            let predicate = NSPredicate(format: "isHidden != %@", NSNumber(booleanLiteral: true))
            fetchRequest.predicate = predicate
            let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]

            let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                      managedObjectContext: context,
                                                                      sectionNameKeyPath: nil,
                                                                      cacheName: nil)
            do {
                try fetchedResultsController.performFetch()
                completion(.success((fetchedResultsController.fetchedObjects ?? []).compactMap { $0 }))
            } catch let error as NSError {
                print("取得失敗: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func fetchAsset(by localId: String, completion: @escaping (Result<AssetEntity, NSError>) -> ()) {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localId)
        fetchRequest.fetchLimit = 1

        do {
            guard let assetEntity = try context.fetch(fetchRequest).first else {
                print("取得失敗") // 適当なエラーを投げる
                return
            }
            completion(.success(assetEntity))
        } catch let error as NSError {
            completion(.failure(error))
        }
        
    }

    func isNotExist(localId: String) -> Bool {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localId)
        fetchRequest.fetchLimit = 1
        let assetEntity = try? context.fetch(fetchRequest).first
        return assetEntity == nil
    }

}
