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

    func save(with context: NSManagedObjectContext? = nil) {
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

    func insertAsset(asset: PHAsset) {
        let context = persistentContainer.viewContext
        guard let insertObject = NSEntityDescription.insertNewObject(forEntityName: "AssetEntity", into: context) as? AssetEntity else {
            print("保存失敗")
            return
        }
        insertObject.localIdentifier = asset.localIdentifier
        insertObject.creationDate = asset.creationDate
        save(with: context)
    }

    func fetchAllAssetEntity(completion: @escaping (Result<[AssetEntity], NSError>) -> ()) {
        let context = persistentContainer.viewContext

        context.perform {
            let fetchRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
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

}
