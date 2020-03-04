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

private let log = SwiftyBeaver.self

protocol PoseEstimationViewProtocol {
    func showProgress(_ show: Bool)
    func reload()
}

class PoseEstimationViewController: UIViewController {
    @IBOutlet weak var viewCollection: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private lazy var imagePicker = {
        return UIImagePickerController()
    }()
    @IBOutlet weak var textLabel: UILabel!

    private var pose: PoseEstimationViewModelProtocol! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Image", style: .plain, target: self, action: #selector(chooseImageClicked))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsClicked))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.viewCollection.collectionViewLayout = self.layout
        self.pose = PoseEstimationViewModelFactory.instance(modelConfiguration: SettingsViewModel.selectedModel, view: self)
        self.pose.keepDebugInfo = true
    }

    @objc func chooseImageClicked(_ sender: UIBarButtonItem) {
        imagePicker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    @objc func settingsClicked(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "SHOW_SETTINGS", sender: nil)
    }
}

extension PoseEstimationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        guard let chosenImage = info[.originalImage] as? UIImage else {
            return
        }
        self.pose.estimate(on: chosenImage) { result in
            self.textLabel.text = self.pose.statusText
        }
        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension PoseEstimationViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.pose.numberOfItemsInSection(section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(ImageCollectionViewCell.self)", for: indexPath) as? ImageCollectionViewCell else {
            return UICollectionViewCell()
        }

        self.pose.imageFor(for: indexPath) { image in
            cell.imageView.image = image
        }
        cell.descriptionLabel.text = self.pose.description(for: indexPath)

        let settings = Settings.defaultSettings
            .with(actionOnTapOverlay: Action.dismissOverlay)
            .with(actionOnDoubleTapImageView: Action.zoomIn)
        addZoombehavior(for: cell.imageView, settings: settings)

        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        self.pose.numberOfSections()
    }
}

extension PoseEstimationViewController: PoseEstimationViewProtocol {
    func showProgress(_ show: Bool) {
        if show {
            self.activityIndicator.startAnimating()
        } else {
            self.activityIndicator.stopAnimating()
        }
    }

    func reload() {
        self.viewCollection.reloadData()
    }
}
