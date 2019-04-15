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
    private lazy var testImage: UIImage  = {
        guard let testImage = UIImage(named: "sample-pose2-resized", in: Bundle(for: ViewController.self), compatibleWith: nil) else {
            assertionFailure("Failed to open image")
            return UIImage()
        }
        return testImage
    }()
    private var imageCount = 0
    private var imageCach: [UIImage?] = Array(repeating: nil, count: 5)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pose.keepDebugInfo = true
        estimatePose()
    }
    
    private func estimatePose() {
        imageCount = 0
        activityIndicator.startAnimating()
        pose.estimate(on: testImage) { humans in
            DispatchQueue.main.async {
                self.imageCount = 5
                self.activityIndicator.stopAnimating()
                self.viewCollection.reloadData()
            }
        }
    }


}

extension ViewController: UICollectionViewDelegate {
    
}

extension ViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(ImageCollectionViewCell.self)", for: indexPath) as? ImageCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        imageFor(row: indexPath.row) { image in
            cell.imageView.image = image
        }
        
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
}

extension ViewController {
    func imageFor(row: Int, completion: @escaping ((UIImage)->())) {
        if let image = imageCach[row] {
            completion(image)
            return
        }
        
        let completionBlock: ((UIImage)->()) = { image in
            DispatchQueue.main.async {
                self.imageCach[row] = image
                completion(image)
            }
        }
        
        switch row {
        case 0:
            pose.humanPosesImage(overImage: testImage, completion: completionBlock)
        case 1:
            pose.heatMapLayersCombined(completion: completionBlock)
        case 2:
            pose.heatMapCandidatesImage(completion: completionBlock)
        case 3:
            pose.filteredHeatMapCandidatesImage(completion: completionBlock)
        case 4:
            pose.jointsWithConnectionsByLayers { images in
                DispatchQueue.main.async {
                    self.imageCach[row] = images.first
                    completion(images.first ?? UIImage())
                }
            }
        default:
            completion(UIImage())
        }
    }
}

