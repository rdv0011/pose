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
import Zoomy

class ViewController: UIViewController {
    @IBOutlet weak var viewCollection: UICollectionView!
    @IBOutlet weak var viewCollectionFlow: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let pose = PoseEstimation(model: PoseModel().model, modelConfig: PoseModelConfigurationMPI15())
    private lazy var testImage: UIImage  = {
        guard let testImage = UIImage(named: "sample-pose1-resized", in: Bundle(for: ViewController.self), compatibleWith: nil) else {
            assertionFailure("Failed to open image")
            return UIImage()
        }
        return testImage
    }()
    private var imageCount = 0
    private static let totalImagesCount = 5 + 84
    private var imageCache: [UIImage?] = Array(repeating: nil, count: ViewController.totalImagesCount)
    private var jointsWithConnectionsByLayersProcesing = false

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
                self.imageCount = ViewController.totalImagesCount
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
        cell.descriptionLabel.text = description(for: indexPath.row)
        
        let settings = Settings.defaultSettings
            .with(actionOnTapOverlay: Action.dismissOverlay)
            .with(actionOnDoubleTapImageView: Action.zoomIn)
        addZoombehavior(for: cell.imageView, settings: settings)
        
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    private func description(for row: Int) -> String {
        switch row {
        case 0:
            return "Final pose on top of an original image"
        case 1:
            return "HeatMap matrices combined into one image.\nDifferent parts are higlighted with a color."
        case 2:
            return "PAFs matrices combined into one image.\nDifferent parts are higlighted with a color."
        case 3:
            return "HeatMap candidates. A color intensity represent a candidates's confidence."
        case 4:
            return "Filtered version of the HeatMap candidates."
        case 5..<83:
            return "HeatMap with PAFs that might be used together to create  a connecton."
        default:
            return ""
        }
    }
}

extension ViewController {
    func imageFor(row: Int, completion: @escaping ((UIImage)->())) {
        if let image = imageCache[row] {
            completion(image)
            return
        }
        
        let completionBlock: ((UIImage)->()) = { image in
            DispatchQueue.main.async {
                self.imageCache[row] = image
                completion(image)
            }
        }
        
        switch row {
        case 0:
            pose.humanPosesImage(overImage: testImage, completion: completionBlock)
        case 1:
            pose.heatMapLayersCombined(completion: completionBlock)
        case 2:
            pose.pafLayersCombinedImage(completion: completionBlock)
        case 3:
            pose.heatMapCandidatesImage(completion: completionBlock)
        case 4:
            pose.filteredHeatMapCandidatesImage(completion: completionBlock)
        case 5..<83:
            if !jointsWithConnectionsByLayersProcesing {
                jointsWithConnectionsByLayersProcesing = true
                pose.jointsWithConnectionsByLayers { images in
                    DispatchQueue.main.async {
                        self.jointsWithConnectionsByLayersProcesing = false
                        images.enumerated().forEach { idx, element in
                            self.imageCache[5 + idx] = element
                        }
                        self.viewCollection.reloadData()
                        completion(images.first ?? UIImage())
                    }
                }
            }
        default:
            completion(UIImage())
        }
    }
}

