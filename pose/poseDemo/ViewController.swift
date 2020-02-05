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
import SwiftyBeaver

class ViewController: UIViewController {
    @IBOutlet weak var viewCollection: UICollectionView!
    @IBOutlet weak var viewCollectionFlow: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private let log = SwiftyBeaver.self
    private lazy var imagePicker = {
        return UIImagePickerController()
    }()
    @IBOutlet weak var textLabel: UILabel!

    private let pose = PoseEstimation(model: PoseModel().model, modelConfig: PoseModelConfigurationMPI15())
    private var testImage: UIImage?
    
    private static var joitConnectionCombinedImagesCount: Int {
        let pose = PoseModelConfigurationMPI15()
        return pose.jointConnectionsCount * 4
    }
    private var imageCount = 0 {
        didSet {
            self.imageCache = Array(repeating: nil, count: ViewController.totalImagesCount)
            self.viewCollection.reloadData()
        }
    }
    private static let totalImagesCount = 5 + ViewController.joitConnectionCombinedImagesCount
    private var imageCache: [UIImage?] = Array(repeating: nil, count: ViewController.totalImagesCount)
    private var jointsWithConnectionsByLayersProcesing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        pose.keepDebugInfo = true
    }
    
    @IBAction func chooseImageClicked(_ sender: UIButton) {
        imagePicker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    private func estimatePose(on image: UIImage) {
        imageCount = 0
        activityIndicator.startAnimating()
        pose.estimate(on: image) { humans in
            DispatchQueue.main.async {
                self.log.debug("CoreML processing time \(self.pose.coreMLProcessingTime) ms")
                self.log.debug("Post processing time \(self.pose.postProcessingTime) ms")
                self.textLabel.text = "CoreML: \(self.pose.coreMLProcessingTime)ms PP: \(self.pose.postProcessingTime)ms"
                self.imageCount = ViewController.totalImagesCount
                self.activityIndicator.stopAnimating()
            }
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let chosenImage = info[.originalImage] as? UIImage else {
            return
        }
        self.testImage = chosenImage
        estimatePose(on: chosenImage)
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
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
            return "A final pose on the top of an original image."
        case 1:
            return "HeatMap matrices are combined into one image.\nParts are higlighted with with different colors."
        case 2:
            return "PAFs matrices combined into a one image.\nParts are higlighted with different colors."
        case 3:
            return "HeatMap candidates. A color intensity represents a candidates's confidence."
        case 4:
            return "Filtered version of the HeatMap candidates."
        case 5..<ViewController.totalImagesCount - 1:
            return "HeatMap with PAFs are used together to create a connection between joints."
        default:
            return ""
        }
    }
}

extension ViewController {
    func imageFor(row: Int, completion: @escaping ((UIImage)->())) {
        guard let testImage = testImage else {
            return
        }
        
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
        case 5..<ViewController.totalImagesCount - 1:
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

