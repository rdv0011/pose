//
//  PoseEstimationViewModel.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2020-03-02.
//  Copyright © 2020 Dmitry Rybakov. All rights reserved.
//

import Foundation
import UIKit
import Pose
import SwiftyBeaver

private let log = SwiftyBeaver.self

class PoseEstimationViewModel<C: PoseModelConfiguration, J> where J == C.C.J {
    var statusText: String = ""
    private var imageCount = 0 {
        didSet {
            self.imageCache = Array(repeating: nil, count: self.totalImageCount)
            self.descriptionCache = [:]
            self.view?.reload()
        }
    }
    private var imageCache: [UIImage?] = []
    private var descriptionCache: [Int: (BodyJoint, BodyJoint)] = [:]
    
    private let poseEstimation: PoseEstimation<C, J>
    private let view: PoseEstimationViewProtocol?
    private var testImage: UIImage? = nil
    private var jointsWithConnectionsByLayersProcesing = false
    
    init(poseEstimation: PoseEstimation<C, J>, view: PoseEstimationViewProtocol) {
        self.poseEstimation = poseEstimation
        self.view = view
        self.imageCache = Array(repeating: nil, count: self.totalImageCount)
        self.descriptionCache = [:]
    }
}

extension PoseEstimationViewModel: PoseEstimationViewModelProtocol {

    var joitConnectionCombinedImagesCount: Int {
        self.poseEstimation.modelConfiguration.jointConnectionsCount * 4
    }

    var totalImageCount: Int {
        self.poseEstimation.modelConfiguration.heatMapLayersCount == self.poseEstimation.modelConfiguration.layersCount ? 4 : 5 + self.joitConnectionCombinedImagesCount
    }

    var keepDebugInfo: Bool {
        get {
            self.poseEstimation.keepDebugInfo
        }
        set {
            self.poseEstimation.keepDebugInfo = newValue
        }
    }

    var coreMLProcessingTime: String {
        self.poseEstimation.coreMLProcessingTime
    }

    var postProcessingTime: String {
        self.poseEstimation.postProcessingTime
    }

    func estimate(on image: UIImage,
                  completion: @escaping ((Result<Void, Error>) -> ())) {
        self.imageCount = 0
        self.testImage = image
        self.view?.showProgress(true)
        self.poseEstimation.estimate(on: image) { (result) in
            DispatchQueue.main.async {
                self.view?.showProgress(false)
                switch result {
                case .success:
                    log.debug("CoreML processing time \(self.coreMLProcessingTime) ms")
                    log.debug("Post processing time \(self.postProcessingTime) ms")
                    self.statusText = "CoreML: \(self.coreMLProcessingTime)ms PP: \(self.postProcessingTime)ms"
                    self.imageCount = self.totalImageCount
                    completion(.success(()))
                case .failure(let error):
                    log.error(error)
                    self.statusText = "Failed to process: \(error)"
                    completion(.failure(error))
                }
            }
        }
    }

    func humanPosesImage(overImage: UIImage, completion: @escaping ((UIImage)->())) {
        self.poseEstimation.humanPosesImage(overImage: overImage, completion: completion)
    }

    func heatMapLayersCombined(completion: @escaping ((UIImage)->())) {
        self.poseEstimation.heatMapLayersCombined(completion: completion)
    }
    
    func heatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        self.poseEstimation.heatMapCandidatesImage(completion: completion)
    }
    
    func filteredHeatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        self.poseEstimation.filteredHeatMapCandidatesImage(completion: completion)
    }
    
    func pafLayersCombinedImage(completion: @escaping ((UIImage)->())) {
        self.poseEstimation.pafLayersCombinedImage(completion: completion)
    }
    
    func jointsWithConnectionsByLayers(completion: @escaping (([(UIImage, (BodyJoint, BodyJoint))])->())) {
        self.poseEstimation.jointsWithConnectionsByLayers(completion: completion)
    }
    
    func numberOfItemsInSection(_ section: Int) -> Int {
        section == 0 ? 1: self.imageCount - 1
    }
    
    func numberOfSections() -> Int {
        self.imageCount > 0 ? 2: 0
    }
    
    func imageFor(for indexPath: IndexPath, completion: @escaping ((UIImage)->())) {
        guard let testImage = testImage else {
            return
        }
        
        let itemCacheRow = indexPath.section == 0 ? 0: indexPath.row + 1
        
        if let item = self.imageCache[itemCacheRow] {
            completion(item)
            return
        }
        
        let completionBlock: ((UIImage)->()) = { image in
            DispatchQueue.main.async {
                self.imageCache[itemCacheRow] = image
                completion(image)
            }
        }
        
        switch itemCacheRow {
        case 0:
            humanPosesImage(overImage: testImage, completion: completionBlock)
        case 1:
            heatMapLayersCombined(completion: completionBlock)
        case 2:
            heatMapCandidatesImage(completion: completionBlock)
        case 3:
            filteredHeatMapCandidatesImage(completion: completionBlock)
        case 4:
            pafLayersCombinedImage(completion: completionBlock)
        case 5..<self.totalImageCount - 1:
            if !jointsWithConnectionsByLayersProcesing {
                jointsWithConnectionsByLayersProcesing = true
                self.jointsWithConnectionsByLayers { result in
                    DispatchQueue.main.async {
                        self.jointsWithConnectionsByLayersProcesing = false
                        result.enumerated().forEach { idx, element in
                            let (image, (joint1, joint2)) = element
                            let itemIndex = idx + 5
                            self.imageCache[itemIndex] = image
                            self.descriptionCache[itemIndex] = (joint1, joint2)
                        }
                        self.view?.reload()
                        completion(result.first?.0 ?? UIImage())
                    }
                }
            }
        default:
            completion(UIImage())
        }
    }
    
    private func jointsDescription(_ joints: (BodyJoint, BodyJoint)) -> String {
        "\(joints.0.rawValue)-\(joints.1.rawValue)"
    }
    
    func description(for indexPath: IndexPath) -> String {
        if indexPath.section == 0 {
            return "A final pose on the top of an original image."
        }
        
        switch indexPath.row {
        case 0:
            return "HeatMap matrices combined"
        case 1:
            return "HeatMap candidates"
        case 2:
            return "Filtered HeatMap candidates"
        case 3:
            return "PAFs"
        case 4..<self.totalImageCount - 1:
            guard let joints = descriptionCache[indexPath.row] else {
                return ""
            }
            return jointsDescription(joints)
        default:
            return ""
        }
    }
}

enum PoseEstimationViewModelFactory {
    static func instance(modelConfiguration: ModelConfiguration, view: PoseEstimationViewProtocol) -> PoseEstimationViewModelProtocol {
        switch modelConfiguration {
        case .openPose:
            return PoseEstimationViewModel(poseEstimation: PoseEstimation(model: PoseBody_CNN_Multi_15().model, modelConfiguration: ModelConfigurationCNNMulti15()), view: view)
        case .mobileNetV2:
            return PoseEstimationViewModel(poseEstimation: PoseEstimation(model: PoseBody_MNV2_Single_14().model, modelConfiguration: ModelConfigurationMNV2Single14()), view: view)
        }
    }
}
