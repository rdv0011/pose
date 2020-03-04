//
//  PoseEstimationViewController+Extension.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2020-03-03.
//  Copyright © 2020 Dmitry Rybakov. All rights reserved.
//

import Foundation
import UIKit

extension PoseEstimationViewController {
    var layout: UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in

            if sectionIndex == 0 {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.5))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)

                section.orthogonalScrollingBehavior = .none
                return section
            } else if sectionIndex == 1 {
                let leadingItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .fractionalHeight(1.0)))
                leadingItem.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)
                let leadingGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.3)), subitem: leadingItem, count: 3)

                let middleItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .fractionalHeight(1.0)))
                middleItem.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)
                let middleGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.3)), subitem: middleItem, count: 3)

                let trailingItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .fractionalHeight(1.0)))
                trailingItem.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading:
                    0.0, bottom: 0.0, trailing: 0.0)
                let trailingGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.3)), subitem: trailingItem, count: 3)

                let nestedGroup = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.85), heightDimension: .fractionalHeight(0.5)), subitems: [leadingGroup, middleGroup, trailingGroup])

                let section = NSCollectionLayoutSection(group: nestedGroup)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)
                section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary

                return section
            }

            fatalError()
        }
        return layout
    }
}
