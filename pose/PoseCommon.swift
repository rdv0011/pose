//
//  PoseCommon.swift
//  pose
//
//  Created by Dmitry Rybakov on 2019-03-27.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import Foundation

public struct JointPoint: Hashable {
    let x: Int
    let y: Int
    var hash: Int {
        return x + y * 2000
    }
}

protocol JointConnectionScoreProtocol {
    associatedtype T: JointConnectionProtocol
    
    var connection: T { get }
    var score: Float32 { get }
    var offsetJoint1: Int { get }
    var offsetJoint2: Int { get }
    var joint1: JointPoint { get }
    var joint2: JointPoint { get }
}

public struct JointConnectionScore<T: JointConnectionProtocol>: JointConnectionScoreProtocol {
    let connection: T
    let score: Float32
    let offsetJoint1: Int
    let offsetJoint2: Int
    let joint1: JointPoint
    let joint2: JointPoint
}

struct Pose {
    static var colors: [UIColor] {
        
        let colorLiterals = [0xFF0055, 0xFF0000, 0xFF5500,
                             0xFFAA00, 0xFFFF00, 0xAAFF00,
                             0x55FF00, 0x2BFF00, 0x00FF00,
                             0x00FF55, 0x00FFAA, 0x00FFFF,
                             0x00AAFF, 0x0055FF, 0xAA00FF,
                             0xFF00FF, 0xFF00AA, 0xFF0055]
        return colorLiterals.map { UIColor(hex: $0) }
    }
}

public enum BodyJoint: String, CaseIterable {
    case head, neck,
    rShoulder, rElbow, rWrist,
    lShoulder, lElbow, lWrist,
    rHip, rKnee, rAnkle,
    lHip, lKnee, lAnkle,
    chest, background
    
    static var array: [BodyJoint] { return self.allCases }
    
    var color: UIColor {
        return Pose.colors[index()]
    }
    
    func index() -> Int {
        return BodyJoint.array.firstIndex(of: self)!
    }
}

public protocol JointConnectionProtocol: Equatable {
    associatedtype T: Equatable
    static var array: [T] { get }
    var joints: (BodyJoint, BodyJoint) { get }
    var color: UIColor { get }
    func index() -> Int
    var pafIndices: (x: Int, y: Int)  { get }
}

func ==<Joint1: JointConnectionProtocol, Joint2: JointConnectionProtocol> (lhs: Joint1, rhs: Joint2) -> Bool {
    return true
}

public enum JointConnectionMPI15: String, CaseIterable, JointConnectionProtocol {
    case headNeck,
    neckRShoulder, rShoulderRElbow, rElbowRWrist,
    neckLShoulder, lShoulderLElbow, lElbowLWrist,
    neckChest,
    chestRHip, rHipRKnee, rKneeRAnkle,
    chestLHip, lHipLKnee, lKneeLAnkle
    
    public static var array: [Self] { return self.allCases }
    
    public var joints: (BodyJoint, BodyJoint) {
        switch self {
        case .headNeck:
            return (.head, .neck)
        case .neckRShoulder:
            return (.neck, .rShoulder)
        case .rShoulderRElbow:
            return (.rShoulder, .rElbow)
        case .rElbowRWrist:
            return (.rElbow, .rWrist)
        case .neckLShoulder:
            return (.neck, .lShoulder)
        case .lShoulderLElbow:
            return (.lShoulder, .lElbow)
        case .lElbowLWrist:
            return (.lElbow, .lWrist)
        case .neckChest:
            return (.neck, .chest)
        case .chestRHip:
            return (.chest, .rHip)
        case .rHipRKnee:
            return (.rHip, .rKnee)
        case .rKneeRAnkle:
            return (.rKnee, .rAnkle)
        case .chestLHip:
            return (.chest, .lHip)
        case .lHipLKnee:
            return (.lHip, .lKnee)
        case .lKneeLAnkle:
            return (.lKnee, .lAnkle)
        }
    }
    
    public var pafIndices: (x: Int, y: Int) {
        switch self {
        case .headNeck:
            return (x: 0, y: 1)
        case .neckRShoulder:
            return (x: 2, y: 3)
        case .rShoulderRElbow:
            return (x: 4, y: 5)
        case .rElbowRWrist:
            return (x: 6, y: 7)
        case .neckLShoulder:
            return (x: 8, y: 9)
        case .lShoulderLElbow:
            return (x: 10, y: 11)
        case .lElbowLWrist:
            return (x: 12, y: 13)
        case .neckChest:
            return (x: 14, y: 15)
        case .chestRHip:
            return (x: 16, y: 17)
        case .rHipRKnee:
            return (x: 18, y: 19)
        case .rKneeRAnkle:
            return (x: 20, y: 21)
        case .chestLHip:
            return (x: 22, y: 23)
        case .lHipLKnee:
            return (x: 24, y: 25)
        case .lKneeLAnkle:
            return (x: 26, y: 27)
        }
    }
    
    public var color: UIColor {
        return self.joints.1.color
    }
    
    public func index() -> Int {
        return JointConnectionMPI15.array.firstIndex(of: self)!
    }
}

public protocol PoseModelConfiguration {
    associatedtype C: PoseModelConfiguration
    associatedtype J: JointConnectionProtocol
    var layersCount: Int { get }
    var backgroundLayerIndex: Int { get }
    var pafLayerStartIndex: Int { get }
    var outputWidth: Int { get }
    var outputHeight: Int { get }
    var inputSize: CGSize { get }
    var scoreThreasholdFactor: Float { get }
    var jointConnectionsCount: Int { get }
    var interMinAboveThreshold: Float32 { get }
    var interThreshold: Float32 { get }
    var minNmsThreshold: Float32 { get }
    var maxNmsThreshold: Float32 { get }
    var nmsWindowSize: Int { get }
    func instance() -> C
    var joints: [BodyJoint] { get }
    var jointConnections: [J] { get }
}

public struct PoseModelConfigurationMPI15: PoseModelConfiguration {
    public var inputSize = CGSize(width: 512, height: 512)

    public var outputWidth: Int {
        return Int(inputSize.width / 8)
    }
    
    public var outputHeight: Int {
        return Int(inputSize.height / 8)
    }

    public var layersCount: Int = 44
    
    public var backgroundLayerIndex: Int = 15
    
    public var pafLayerStartIndex: Int = 16
    
    public var scoreThreasholdFactor: Float = 2
    
    public var jointConnectionsCount: Int {
        return jointConnections.count
    }
    
    public var interMinAboveThreshold: Float32 = Float32(0.75)
    public var interThreshold: Float32 = Float32(0.01)
    public var minNmsThreshold: Float32 = Float32(0.1) // for MPI with 4 stages that is a fast version
    public var maxNmsThreshold: Float32 = Float32(0.3) // for MPI with 4 stages that is a fast version
    public var nmsWindowSize: Int = 7
    
    public var joints = BodyJoint.array
    public var jointConnections = JointConnectionMPI15.array

    public init() {
    }
    
    public func instance() -> PoseModelConfigurationMPI15 {
        PoseModelConfigurationMPI15()
    }
}

struct HeatMapJointCandidate {
    let col: Int
    let row: Int
    let layerIndex: Int
    let confidence: Float32
    
    var color: UIColor {
        return Pose.colors[layerIndex % Pose.colors.count]
    }
}
