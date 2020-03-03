//
//  SettingsViewController.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2020-03-01.
//  Copyright © 2020 Dmitry Rybakov. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var modelPicker: UIPickerView!
    let model = SettingsViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let component = model.selectedComponent(pickerTag: modelPicker.tag)
        let row = model.selectedRow(pickerTag: modelPicker.tag)
        modelPicker.selectRow(row, inComponent: component, animated: true)
    }
}

extension SettingsViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        model.numberOfComponents(pickerTag: pickerView.tag)
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        model.numberOfRowsInComponent(pickerTag: pickerView.tag, component: component)
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        model.pickerTitle(pickerTag: pickerView.tag, forComponent: component, forRow: row)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        model.didSelect(pickerTag: pickerView.tag, row: row, component: component)
    }
}
