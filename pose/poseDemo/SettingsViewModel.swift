//
//  SettingsViewModel.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2020-03-01.
//  Copyright © 2020 Dmitry Rybakov. All rights reserved.
//

import Foundation

enum ModelConfiguration: Int, Codable {
    case openPose
    case mobileNetV2
    
    init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .openPose
        case 1:
            self = .mobileNetV2
        default:
            self = .openPose
        }
    }
}

extension UserDefaults {
    func setValue<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
        } catch {
            print("Failed to store: \(error)")
        }
    }
    
    func value<T: Decodable>(forKey key: String) -> T? {
        guard let data = value(forKey: key) as? Data else {
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to get value: \(error)")
            return nil
        }
    }
}

extension String {
    static let modelConfigurationKey = "modelConfigurationKey"
}

class SettingsViewModel {

    static var selectedModel: ModelConfiguration {
        guard let modelConfiguration: ModelConfiguration = UserDefaults.standard.value(forKey: .modelConfigurationKey) else {
            return .openPose
        }
        return modelConfiguration
    }

    init() {
        // Set default values
        if UserDefaults.standard.value(forKey: .modelConfigurationKey) == nil {
            UserDefaults.standard.setValue(ModelConfiguration.openPose, forKey: .modelConfigurationKey)
        }
    }

    func numberOfComponents(pickerTag: Int) -> Int {
        1
    }

    func numberOfRowsInComponent(pickerTag: Int, component: Int) -> Int {
        2
    }

    func pickerTitle(pickerTag: Int, forComponent component: Int, forRow row: Int) -> String {
        if row == 0 {
            return "OpenPose model"
        }
        return "MobileNetV2 model"
    }

    func didSelect(pickerTag: Int, row: Int, component: Int) {
        UserDefaults.standard.setValue(ModelConfiguration(rawValue: row), forKey: .modelConfigurationKey)
    }

    func selectedRow(pickerTag: Int) -> Int {
        return SettingsViewModel.selectedModel.rawValue
    }

    func selectedComponent(pickerTag: Int) -> Int {
        0
    }
}
