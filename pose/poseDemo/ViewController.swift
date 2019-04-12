//
//  ViewController.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2019-03-21.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit
import CoreML
import Pose

class ViewController: UIViewController {
    @IBOutlet weak var viewCollection: UICollectionView!
    @IBOutlet weak var viewCollectionFlow: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let pose = PoseEstimation(model: PoseModel().model, modelConfig: PoseModelConfigurationMPI15())
    private var imagesCount = 0
    private lazy var testImage: UIImage  = {
        guard let testImage = UIImage(named: "five_people", in: Bundle(for: ViewController.self), compatibleWith: nil) else {
            assertionFailure("Failed to open image")
            return UIImage()
        }
        return testImage
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pose.keepDebugInfo = true
        activityIndicator.startAnimating()
        pose.estimate(on: testImage) { humans in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.imagesCount = 2
                self.viewCollection.reloadData()
            }
        }
    }


}

extension ViewController: UICollectionViewDelegate {
    
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imagesCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(ImageCollectionViewCell.self)", for: indexPath) as? ImageCollectionViewCell else {
            return UICollectionViewCell()
        }
        if indexPath.row == 0 {
            cell.imageView.image = pose.heatmapMatricesCombined
        } else if indexPath.row == 1 {
            cell.imageView.image = testImage
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
}

