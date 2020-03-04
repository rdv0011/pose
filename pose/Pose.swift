//
//  Pose.swift
//
// comment
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit
import CoreML
import Vision
import CoreMLHelpers
import SwiftyBeaver

enum PoseEstimationError: Error {
    case noObservationsForRequest
    case modelConfigurationToModelOutput
    case failedToCreateModel(Error)
    case failedToCreateCIImage
}

open class PoseEstimation<C: PoseModelConfiguration, J> where J == C.C.J {
    public typealias JointScore = JointConnectionScore<J>
    public typealias EstimationResult = [Int: [JointScore]]

    private let model: MLModel
    
    // Model configuration
    public let modelConfiguration: C
    
    private var coremlProcessingStart = Date()
    private var coremlProcessingFinish = Date()
    private var postProcessingStart = Date()
    private var postProcessingFinish = Date()
    private let log = SwiftyBeaver.self

    public var keepDebugInfo: Bool = false
    
    private(set) var networkOutput: Array<Float> = []
    private(set) var heatMapCandidates: [HeatMapJointCandidate] = []
    private(set) var filteredHeatMapCandidates: [HeatMapJointCandidate] = []
    private(set) var allConnectionCandidates: [JointScore] = []
    private(set) var humanConnections: EstimationResult = [:]
    
    //////
    var convertedHeatmap: Array<Array<Float>>?
    /////
    
    public init(model: MLModel, modelConfiguration: C) {
        self.model = model
        self.modelConfiguration = modelConfiguration
    }
    
    private func delta(x1: Int, y1: Int, x2: Int, y2: Int) -> (dx: Float, dy: Float, stepCount: Int) {
        var (dx, dy) = (Float(abs(x2 - x1) + 1), Float(abs(y2 - y1) + 1))
        var stepCount  = (5 * max(abs(dx), abs(dy))).squareRoot()
        stepCount = max(5, min(25, stepCount))
        dx /= stepCount
        dy /= stepCount
        return (dx: dx, dy: dy, stepCount: Int(stepCount.rounded()))
    }
    
    private func stride(x1: Int, y1: Int, x2: Int, y2: Int, processBlock: ((Int, Int, Int, Int) -> Void)) {
        let (dx, dy, stepCount) = delta(x1: x1, y1: y1, x2: x2, y2: y2)
        let (x0, y0) = (Float(x1), Float(y1))
        (0..<stepCount).forEach { idx in
            let x = Int((x0 + Float(idx) * dx).rounded(.toNearestOrAwayFromZero))
            let y = Int((y0 + Float(idx) * dy).rounded(.toNearestOrAwayFromZero))
            processBlock(x, y, idx, stepCount)
        }
    }
    
    private func score(x1: Int, y1: Int, x2: Int, y2: Int,
               pafMatX: Array<Float32>, pafMatY: Array<Float32>,
               yStride: Int) -> Float32 {
        let vectorAToB = (x: Float32(x2 - x1), y: Float32(y2 - y1))
        let vectorAToBLength = (pow(vectorAToB.x, 2) + pow(vectorAToB.y, 2)).squareRoot()
        
        guard vectorAToBLength > 1e-6 else {
            return -1
        }
        
        let vectorAToBNorm = (x: vectorAToB.x / vectorAToBLength, y: vectorAToB.y / vectorAToBLength)
        var PAFs: [Float32] = []
        
        stride(x1: x1, y1: y1, x2: x2, y2: y2) { x, y, idx, count in
            // These offset values are used to cover larger area in PAF's to collect as many score as possible
            var dx = [-1, 0, 1]
            var dy = [0, 0, 0]
            if abs(x2 - x1) > abs(y2 - y1) {
                // If scores are collected horizontally then use Ys offsets instead of Xs
                //  When moving horizontally
                //  y - 1   y - 1      y - 1
                //  x1, y   x2, y .... xn, y
                //  y + 1   y + 1      y + 1
                //  When moving vertically
                //  x - 1   x, y1  x + 1
                //  x - 1   x, y2  x + 1
                //          ....
                //          ....
                //  x - 1   x, yn  x + 1
                swap(&dx, &dy)
            }

            for (dx, dy) in zip(dx, dy) {
                var offset = (y + dy) * yStride + x + dx
                // Check if it is out of array's bounds
                offset = min(max(0, offset), pafMatX.count - 1)
                // Accumulate PAFs values
                PAFs.append(vectorAToBNorm.x * pafMatX[offset] + vectorAToBNorm.y * pafMatY[offset])
            }
        }
        
        let pointCount = PAFs.count / 3 // it needs to be devided because there are three (dx, dy) pairs for each point
        PAFs = PAFs.filter { $0 > modelConfiguration.interThreshold }
        let sum = PAFs.reduce(0, +)
        let scoresCount = PAFs.count
        
        if Float32(scoresCount) / Float32(pointCount) > modelConfiguration.interMinAboveThreshold {
            return sum / Float32(scoresCount)
        }
        
        let threshold = Float32(modelConfiguration.outputWidth * modelConfiguration.outputHeight).squareRoot() / 150
        if vectorAToBLength < threshold {
            return 0.15
        }
        
        return -1
    }
    
    public func estimate(on image: UIImage, completion: @escaping ((Result<EstimationResult, Error>) -> ())) {
        
        var uiImage = image
        if image.size != modelConfiguration.inputSize {
            uiImage = image.resizedCentered(toSize: modelConfiguration.inputSize)
        }
        
        var scaleFactor = image.size.height / CGFloat(modelConfiguration.outputHeight)
        var offsetX = CGFloat.zero
        var offsetY = CGFloat.zero
        if image.size.width < image.size.height {
            offsetX = 0.5 * (image.size.width - CGFloat(modelConfiguration.outputWidth) * scaleFactor)
        } else {
            scaleFactor = image.size.width / CGFloat(modelConfiguration.outputWidth)
            offsetY = 0.5 * (image.size.height - CGFloat(modelConfiguration.outputHeight) * scaleFactor)
        }
        
        guard let ciImage = CIImage(image: uiImage) else {
            completion(.failure(PoseEstimationError.failedToCreateCIImage))
            return
        }

        let coremlRequest = mlRequest(model: self.model) { result in
            switch result {
            case .success(let connections):
                // Scale coordinates of the output connections to be aligned with the input image size
                self.humanConnections = connections.mapValues { connections in
                    return connections.map {
                        
                        let joint1 = JointPoint(x: Int(CGFloat($0.joint1.x) * scaleFactor + offsetX),
                                                y: Int(CGFloat($0.joint1.y) * scaleFactor + offsetY))
                        let joint2 = JointPoint(x: Int(CGFloat($0.joint2.x) * scaleFactor + offsetX),
                                                y: Int(CGFloat($0.joint2.y) * scaleFactor + offsetY))
                        return JointConnectionScore(connection: $0.connection,
                                                            score: $0.score,
                                                            offsetJoint1: $0.offsetJoint1,
                                                            offsetJoint2: $0.offsetJoint2,
                                                            joint1: joint1,
                                                            joint2: joint2)
                    }
                }
                completion(.success(self.humanConnections))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        guard let request = coremlRequest else {
            return
        }
        // Set an image scaling mode for the Vision framework
        request.imageCropAndScaleOption = .centerCrop
        // Even though the CoreML model has fixed input image size that is not equal to the real input image the Vision framework will scale it accordingly
        let handler = VNImageRequestHandler(ciImage: ciImage)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                self.coremlProcessingStart = Date()
                self.resetOutput()
                try handler.perform([request])
            } catch {
                self.log.error(error)
            }
        }
    }
}

extension PoseEstimation {
    
    private func mlRequest(model: MLModel,
                           completion: @escaping ((Result<EstimationResult, Error>) -> ())) -> VNCoreMLRequest? {
        let vnModel: VNCoreMLModel!
        do {
            vnModel = try VNCoreMLModel(for: model)
        } catch {
            completion(.failure(PoseEstimationError.failedToCreateModel(error)))
            return nil
        }
        
        
        let coremlRequest = VNCoreMLRequest(model: vnModel) { request, error in
            
            self.coremlProcessingFinish = Date()
            
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
                let outputMultiArray = observations.first?.featureValue.multiArrayValue else {

                    completion(.failure(PoseEstimationError.noObservationsForRequest))
                    return
            }

            guard outputMultiArray.shape[0].intValue == self.modelConfiguration.layersCount,
                outputMultiArray.shape[1].intValue == self.modelConfiguration.outputWidth,
                outputMultiArray.shape[2].intValue == self.modelConfiguration.outputHeight else {

                    completion(.failure(PoseEstimationError.modelConfigurationToModelOutput))
                    return
            }

            let layersCount = self.modelConfiguration.layersCount
            let layerStride = outputMultiArray.strides[0].intValue
            let modelOutputWidth = self.modelConfiguration.outputWidth
            
            withExtendedLifetime(outputMultiArray) {
                
                self.postProcessingStart = Date()
                
                let nnOutput = UnsafeMutablePointer<Float32>(OpaquePointer(outputMultiArray.dataPointer))
                let heatMatCount = self.modelConfiguration.heatMapLayersCount
                let heatMatPtr = nnOutput
                
                if self.keepDebugInfo {
                    // Convert a network output to an array for debugging purposes
                    self.networkOutput = nnOutput.array(index: 0, count: layersCount * layerStride)
                }
                // Filter the heatmapp network output by applying a threshold
                let heatMapArray = heatMatPtr.array(index: 0, count: heatMatCount * layerStride).map { max(min($0, 1.0), 0.0) }
                // We expect that the output value from NN should lie between 0 and 1
                let avg = heatMapArray.reduce(0, +) / Float32(heatMapArray.count)
                var nmsThreshold: Float32 = self.modelConfiguration.minNmsThreshold
                nmsThreshold = max(avg * 4.0, nmsThreshold)
                nmsThreshold = min(nmsThreshold, self.modelConfiguration.maxNmsThreshold)
                self.heatMapCandidates = []
                for layerIndex in 0..<heatMatCount {
                    let layerPtr = heatMatPtr.advanced(by: layerIndex * layerStride)
                    for idx in 0..<layerStride {
                        if layerPtr[idx] > nmsThreshold {
                            let col = idx % modelOutputWidth
                            let row = idx / modelOutputWidth
                            self.heatMapCandidates.append(HeatMapJointCandidate(col: col,
                                                                                row: row,
                                                                                layerIndex: layerIndex,
                                                                                confidence: layerPtr[idx]))
                        }
                    }
                }
                // Continue filtering using a non maximum suppression approach
                self.filteredHeatMapCandidates = []
                for layerIndex in (0..<heatMatCount) {
                    let candidates = self.heatMapCandidates.filter { $0.layerIndex == layerIndex }
                    // Non maximum suppression to get as minimum candidates as possible
                    let boxes = candidates.map { c -> BoundingBox in
                        let originOffset = self.modelConfiguration.nmsWindowSize / 2
                        let windowOrigin = CGPoint(x: max(0, c.col - originOffset),
                                                   y: max(0, c.row - originOffset))
                        let windowSize = CGSize(width: self.modelConfiguration.nmsWindowSize,
                                                height: self.modelConfiguration.nmsWindowSize)
                        return BoundingBox(classIndex: 0,
                                           score: Float(c.confidence),
                                           rect: CGRect(origin: windowOrigin, size: windowSize))
                    }
                    let boxIndices = nonMaxSuppression(boundingBoxes: boxes, iouThreshold: 0.01, maxBoxes: boxes.count)
                    self.filteredHeatMapCandidates += boxIndices.map { candidates[$0] }
                }
                
                let pose = self.modelConfiguration.instance()
                // Map heat map layer index to joint type
                let candidatesByJoints = Dictionary(grouping: self.filteredHeatMapCandidates, by: { pose.joint(forHeatMapIndex: $0.layerIndex) })
                // Get joint connections with scores based on PAF matrices
                self.allConnectionCandidates = []
                var connections: [JointScore] = []
                var connectionCandidates: [JointScore] = []
                pose.jointConnections.forEach { connection in
                    
                    if pose.singlePerson {
                        // Handle a sinle persion use case
                        let (joint1, joint2) = (connection.joints.0, connection.joints.1)
                        
                        if let candidate1 = candidatesByJoints[joint1],
                            let candidate2 = candidatesByJoints[joint2] {

                            candidate1.enumerated().forEach { offset1, first in
                                candidate2.enumerated().forEach { offset2, second in
                            
                                    let (x1, y1) = (first.col, first.row)
                                    let (x2, y2) = (second.col, second.row)
                                    let jointPoint1 = JointPoint(x: x1, y: y1)
                                    let jointPoint2 = JointPoint(x: x2, y: y2)
                                    let connWithCoords = JointScore(connection: connection,
                                                                    score: 0.0,
                                                                    offsetJoint1: offset1,
                                                                    offsetJoint2: offset2,
                                                                    joint1: jointPoint1,
                                                                    joint2: jointPoint2)
                                    connections.append(connWithCoords)
                                }
                            }
                        }
                        return
                    }

                    let (indexX, indexY) = connection.pafIndices
                    let pafLayerStartIndex = self.modelConfiguration.pafLayerStartIndex
                    let pafMatX = nnOutput.array(index: pafLayerStartIndex + indexX,
                                                 count: layerStride)
                    let pafMatY = nnOutput.array(index: pafLayerStartIndex + indexY,
                                                 count: layerStride)
                    
                    let (joint1, joint2) = (connection.joints.0, connection.joints.1)
                    
                    if let candidate1 = candidatesByJoints[joint1],
                        let candidate2 = candidatesByJoints[joint2] {
                        
                        connectionCandidates = []
                        
                        // Enumerate through non filtered joint connections
                        candidate1.enumerated().forEach { offset1, first in
                            candidate2.enumerated().forEach { offset2, second in
                                
                                let (x1, y1) = (first.col, first.row)
                                let (x2, y2) = (second.col, second.row)
                                
                                let s = self.score(x1: x1, y1: y1, x2: x2, y2: y2,
                                                        pafMatX: pafMatX, pafMatY: pafMatY,
                                                        yStride: modelOutputWidth)
                                if s > 0 {
                                    let jointPoint1 = JointPoint(x: x1, y: y1)
                                    let jointPoint2 = JointPoint(x: x2, y: y2)
                                    let connWithCoords = JointScore(connection: connection,
                                                                              score: s,
                                                                              offsetJoint1: offset1,
                                                                              offsetJoint2: offset2,
                                                                              joint1: jointPoint1,
                                                                              joint2: jointPoint2)
                                    connectionCandidates.append(connWithCoords)
                                }
                            }
                        }
                        self.allConnectionCandidates += connectionCandidates
                        
                        var (usedIdx1, usedIdx2) = (Set<Int>(), Set<Int>())
                        connectionCandidates.sorted(by: { $0.score > $1.score }).forEach { c in
                            if usedIdx1.contains(c.offsetJoint1) || usedIdx2.contains(c.offsetJoint2) {
                                return
                            }
                            connections.append(c)
                            usedIdx1.insert(c.offsetJoint1)
                            usedIdx2.insert(c.offsetJoint2)
                        }
                    }
                }
                // Group connections by human.
                var humanJoints: [Set<JointPoint>] = []
                self.humanConnections = [:]
                connections.enumerated().forEach { connIdx, c in
                    var added = false
                    (0..<humanJoints.count).forEach { humanIdx in
                        let conn = humanJoints[humanIdx]
                        if (conn.contains(c.joint1) && !conn.contains(c.joint2)) ||
                            (conn.contains(c.joint2) && !conn.contains(c.joint1)) {
                            humanJoints[humanIdx].insert(c.joint1)
                            humanJoints[humanIdx].insert(c.joint2)
                            self.humanConnections[humanIdx]?.append(c)
                            added = true
                            return
                        }
                    }
                    if !added {
                        humanJoints.append([c.joint1, c.joint2])
                        self.humanConnections[humanJoints.count - 1] = [c]
                    }
                }
                
                self.postProcessingFinish = Date()
                completion(.success(self.humanConnections))
            }
        }
        return coremlRequest
    }
}

extension HeatMapJointCandidate {
    func scaled(kx: CGFloat, ky: CGFloat) -> HeatMapJointCandidate {
        return HeatMapJointCandidate(col: Int(CGFloat(self.col) * kx), row: Int(CGFloat(self.row) * kx),
                                     layerIndex: self.layerIndex, confidence: self.confidence)
    }
}

extension JointConnectionScore {
    func scaled(kx: CGFloat, ky: CGFloat) -> JointConnectionScore {
        return JointConnectionScore(connection: self.connection , score: self.score,
                                        offsetJoint1: self.offsetJoint1, offsetJoint2: self.offsetJoint2,
                                        joint1: JointPoint(x: Int(kx * CGFloat(self.joint1.x)),
                                                           y: Int(ky * CGFloat(self.joint1.y))),
                                        joint2: JointPoint(x: Int(kx * CGFloat(self.joint2.x)),
                                                           y: Int(ky * CGFloat(self.joint2.y))))
    }
}

extension PoseEstimation {
    
    private func resetOutput() {
        self.networkOutput = []
        self.heatMapCandidates = []
        self.filteredHeatMapCandidates = []
        self.allConnectionCandidates = []
        self.humanConnections = [:]
    }
    
    private var modelOutputLayerStride: Int {
        return self.modelConfiguration.outputWidth * self.modelConfiguration.outputHeight
    }
    
    public var coreMLProcessingTime: String {
        let timeElapsed = coremlProcessingFinish.timeIntervalSince(coremlProcessingStart)
        return String(format: "%d", Int(timeElapsed * 1000))
    }
    
    public var postProcessingTime: String {
        let timeElapsed = postProcessingFinish.timeIntervalSince(postProcessingStart)
        return String(format: "%d", Int(timeElapsed * 1000))
    }
    
    public func heatMapLayersCombined(completion: @escaping ((UIImage)->())) {
        let heatMatCount = modelConfiguration.heatMapLayersCount
        DispatchQueue.global(qos: .userInteractive).async {
            completion(self.networkOutput.drawMatricesCombined(matricesCount: heatMatCount,
                                                               width: self.modelConfiguration.outputWidth,
                                                      height: self.modelConfiguration.outputHeight,
                                                      colors: Pose.colors).resized(to: self.modelConfiguration.inputSize))
        }
    }
    
    public func heatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        guard networkOutput.count >= modelConfiguration.layersCount * self.modelOutputLayerStride else {
            log.error("The netowrk output array has an incorrect size or it was not set")
            completion(UIImage())
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw heatmap candidates for joints after NN output filtering
            // Use alpha to indicate candiates confidence
            let modelOutputWidth = self.modelConfiguration.outputWidth
            let modelOutputHeight = self.modelConfiguration.outputHeight
            let kx = CGFloat(self.modelConfiguration.inputSize.width) / CGFloat(modelOutputWidth)
            let ky = CGFloat(self.modelConfiguration.inputSize.height) / CGFloat(modelOutputHeight)
            let candidates = self.heatMapCandidates.map { $0.scaled(kx: kx, ky: ky) }
            completion(candidates.draw(radius: 3.0, lineWidth: 2.0,
                                       on: UIImage.image(with: .white, size: self.modelConfiguration.inputSize)))
        }
    }
    
    public func filteredHeatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        DispatchQueue.global(qos: .userInteractive).async {
            let modelOutputWidth = self.modelConfiguration.outputWidth
            let modelOutputHeight = self.modelConfiguration.outputHeight
            let kx = CGFloat(self.modelConfiguration.inputSize.width) / CGFloat(modelOutputWidth)
            let ky = CGFloat(self.modelConfiguration.inputSize.height) / CGFloat(modelOutputHeight)
            let candidates = self.filteredHeatMapCandidates.map { $0.scaled(kx: kx, ky: ky) }
            // Draw joint candidates after second round filtering
            completion(candidates.draw(radius: 3.0, lineWidth: 6.0,
                                       on: UIImage.image(with: .white, size: self.modelConfiguration.inputSize)))
        }
    }
    
    public func jointsWithConnectionsImage(completion: @escaping ((UIImage)->())) {
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw all connecions using a score as an alpha
            let allConnectionsImage = self.allConnectionCandidates.draw(lineWidth: 5,
                                                                   on: UIImage.image(with: .white, size: self.modelConfiguration.inputSize))
            // Draw filtered joints over the all connection candidates
            completion(self.filteredHeatMapCandidates.draw( radius: 5, lineWidth: 3,
                                        on: allConnectionsImage))
        }
    }
    
    /// Return images with joint connections as a parameter of a completion handler
    /// - Note: The corresponding heatmap and PAF's outputs are used as background.
    /// The number of images is equal to a number of joint connections multiplied by four.
    /// The pair of heatmaps correcponds to one connection that forms first two images of an output.
    /// There is also two PAF's for X and for Y for each connection that forms other two images of an output.
    /// The sum of two above forms four images for each connection in the result array of images.
    public func jointsWithConnectionsByLayers(completion: @escaping (([(UIImage, (BodyJoint, BodyJoint))])->())) {
        guard self.modelConfiguration.pafLayerStartIndex > 0 else {
            log.debug("Model does not have PAF layers")
            completion([])
            return
        }
        guard networkOutput.count >= modelConfiguration.layersCount * self.modelOutputLayerStride else {
            log.error("The network output array has an incorrect size or it was not set")
            completion([])
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            let modelOutputWidth = self.modelConfiguration.outputWidth
            let modelOutputHeight = self.modelConfiguration.outputHeight
            let pafLayerStartIndex = self.modelConfiguration.pafLayerStartIndex
            let modelInputSize = self.modelConfiguration.inputSize
            var result: [(UIImage, (BodyJoint, BodyJoint))] = []
            let pose = self.modelConfiguration.instance()
            pose.jointConnections.forEach { connection in
                let (indexX, indexY) = connection.pafIndices
                let pafMatX = Array(self.networkOutput.slice(blockIndex: pafLayerStartIndex + indexX,
                                                       blockSize: self.modelOutputLayerStride))
                let pafMatY = Array(self.networkOutput.slice(blockIndex: pafLayerStartIndex + indexY,
                                                       blockSize: self.modelOutputLayerStride))
                let pafXImage = pafMatX.draw(width: modelOutputWidth,
                                             height: modelOutputHeight).resized(to: modelInputSize)
                let pafYImage = pafMatY.draw(width: modelOutputWidth,
                                             height: modelOutputHeight).resized(to: modelInputSize)
                
                // Two joints one connection in between
                var joints1 = self.heatMapCandidates.filter({ $0.layerIndex == connection.joints.0.index()})
                var joints2 = self.heatMapCandidates.filter({ $0.layerIndex == connection.joints.1.index()})
                var filteredJoints1 = self.filteredHeatMapCandidates.filter({ $0.layerIndex == connection.joints.0.index()})
                var filteredJoints2 = self.filteredHeatMapCandidates.filter({ $0.layerIndex == connection.joints.1.index()})
                var jointConns = self.allConnectionCandidates.filter({ $0.connection == connection })
                
                // The index of joint is equal to a heatmap index
                let (heatMapIndex1, heatMapIndex2) = (connection.joints.0.index(), connection.joints.1.index())
                // Heatmap's starts from the zero index therefore no offset is needed for a 'heatMapIndex'
                // 'heatMap1' corresponds to the first joint, 'heatMap2' to the second one
                let heatMap1 = Array(self.networkOutput.slice(blockIndex: heatMapIndex1,
                                                        blockSize: self.modelOutputLayerStride))
                let heatMap2 = Array(self.networkOutput.slice(blockIndex: heatMapIndex2,
                                                        blockSize: self.modelOutputLayerStride))
                var heatMap1Image = heatMap1.draw(width: modelOutputWidth,
                                                  height: modelOutputHeight).resized(to: modelInputSize)
                var heatMap2Image = heatMap2.draw(width: modelOutputWidth,
                                                  height: modelOutputHeight).resized(to: modelInputSize)
                
                let jointRadius = CGFloat(Int(modelInputSize.width) / modelOutputWidth / 2)
                let connectionWidth = jointRadius * 0.8
                
                // NN output has a reduced size comparing to the input
                // Although for a good visual experience it is better to enlarge the size
                // To do this let's scale the heatmap and PAF`s output coordinates
                let kx = CGFloat(self.modelConfiguration.inputSize.width) / CGFloat(modelOutputWidth)
                let ky = CGFloat(self.modelConfiguration.inputSize.height) / CGFloat(modelOutputHeight)
                joints1 = joints1.map { $0.scaled(kx: kx, ky: ky) }
                joints2 = joints2.map { $0.scaled(kx: kx, ky: ky) }
                filteredJoints1 = filteredJoints1.map { $0.scaled(kx: kx, ky: ky) }
                filteredJoints2 = filteredJoints2.map { $0.scaled(kx: kx, ky: ky) }
                jointConns = jointConns.map { $0.scaled(kx: kx, ky: ky) }
                
                // Draw joint candidates on the heat map layers
                heatMap1Image = filteredJoints1.draw(alpha: 1.0, radius: 2, lineWidth: 2,
                                                     on: heatMap1Image)
                result.append((joints1.draw(radius: jointRadius, lineWidth: 1, on: heatMap1Image), connection.joints))
                heatMap2Image = filteredJoints2.draw(alpha: 1.0, radius: 2, lineWidth: 2,
                                                     on: heatMap2Image)
                result.append((joints2.draw(radius: jointRadius, lineWidth: 1,
                                            on: heatMap2Image), connection.joints))
                
                // Draw joint candidates and connections on the PAFs layers
                var pafXJointsConnectionsImage = filteredJoints1.draw(alpha: 1.0, radius: 2 * jointRadius, lineWidth: 3,
                                                                      on: pafXImage)
                pafXJointsConnectionsImage = filteredJoints2.draw(alpha: 1.0, radius: 2 * jointRadius, lineWidth: 3,
                                                                  on: pafXJointsConnectionsImage)
                var pafYJointsConnectionsImage = filteredJoints1.draw(alpha: 1.0, radius: 2 * jointRadius, lineWidth: 3,
                                                                      on: pafYImage)
                
                pafYJointsConnectionsImage = filteredJoints2.draw(alpha: 1.0, radius: 2 * jointRadius, lineWidth: 3,
                                                                  on: pafYJointsConnectionsImage)
                result.append((jointConns.draw(lineWidth: 2 * connectionWidth,
                                               on: pafXJointsConnectionsImage), connection.joints))
                result.append((jointConns.draw(lineWidth: 2 * connectionWidth,
                                               on: pafYJointsConnectionsImage), connection.joints))
            }
            completion(result)
        }
    }
    
    public func humanPosesImage(overImage: UIImage, completion: @escaping ((UIImage)->())) {
        guard self.humanConnections.count > 0 else {
            log.error("No human pose was detected")
            completion(UIImage())
            return
        }
        // Draws human joints and connections over an input image
        DispatchQueue.global(qos: .userInteractive).async {
            var resultImage = overImage.grayed
            let renderer = UIGraphicsImageRenderer(size: resultImage.size)
            resultImage = renderer.image { context in
                resultImage.draw(at: .zero)
                self.humanConnections.forEach { h in
                    h.value.draw(lineWidth: max(overImage.size.width / 100, 1.0),
                                   drawJoint: true,
                                   alpha: 1.0,
                                   on: context.cgContext)
                }
            }
            completion(resultImage)
        }
    }
    
    public func pafLayersCombinedImage(completion: @escaping ((UIImage)->())) {
        guard self.modelConfiguration.pafLayerStartIndex > 0 else {
            log.debug("Model does not have PAF layers")
            completion(UIImage())
            return
        }
        guard self.networkOutput.count >= self.modelConfiguration.layersCount * self.modelOutputLayerStride else {
            log.error("The network output array has an incorrect size or it was not set")
            completion(UIImage())
            return
        }
        let layersCount = self.modelConfiguration.layersCount
        let modelOutputWidth = self.modelConfiguration.outputWidth
        let modelOutputHeight = self.modelConfiguration.outputHeight
        let pafLayerStartIndex = self.modelConfiguration.pafLayerStartIndex
        let modelOutputLayerStride = self.modelOutputLayerStride
        
        let pafCount = layersCount - pafLayerStartIndex
        DispatchQueue.global(qos: .userInteractive).async {
            
            // PAF matrices go from the pafLayerStartIndex till the end of the NN output array
            let pafArray = Array(self.networkOutput[(pafLayerStartIndex * modelOutputLayerStride)...])
            let pointer = UnsafeMutablePointer<Float>(mutating: pafArray)
            for layerIndex in 0..<pafCount {
                let layerPtr = pointer.advanced(by: layerIndex * modelOutputLayerStride)
                let channelArray = pafArray.slice(blockIndex: layerIndex, blockSize: modelOutputLayerStride)
                let keyFactor = Float(10000) // is used to make a key(integral value) out of float value
                let valSet = NSCountedSet(array: channelArray.map { ($0 * keyFactor).rounded() })
                let hist = valSet.sorted(by: { (a, b) -> Bool in
                    return valSet.count(for: a) < valSet.count(for: b)
                })
                if let last = hist.last as? Int {
                    let maxHist = Float(last) / keyFactor
                    for idx in 0..<modelOutputLayerStride {
                        if layerPtr[idx] < 0 {
                            layerPtr[idx] = abs(layerPtr[idx] - maxHist)
                        }
                    }
                }
            }
            let image = pafArray.drawMatricesCombined(matricesCount: pafCount, width: modelOutputWidth,
                                                     height: modelOutputHeight, colors: Pose.colors).resized(to: self.modelConfiguration.inputSize)
            completion(image)
        }
    }
}

#if DEBUG
extension PoseEstimation {
    public func stride_testable(x1: Int, y1: Int, x2: Int, y2: Int, processBlock: ((Int, Int, Int, Int) -> Void)) {
        self.stride(x1: x1, y1: y1, x2: x2, y2: y2, processBlock: processBlock)
    }
}
#endif
