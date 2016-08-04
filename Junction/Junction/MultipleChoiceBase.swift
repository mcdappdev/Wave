//
//  SingleSelectionBase.swift
//  Junction
//
//  Created by Jimmy McDermott on 7/12/16.
//  Copyright © 2016 BlueLine Labs. All rights reserved.
//

import Foundation
import UIKit

//TODO: Make sure this supports only objects that can be serialized
public class MultipleChoiceBase<T: Any>: SectionType, SettingType {
    
    public var possibleValues: [MultipleChoiceOption<T>]
    public var enableCustom = false
    public var name: String
    internal var rows = [RowType]()
    private var selectedOption: Int?
    private var selectedOptions: [Int]?
    internal var key: String
    public var sectionDelegate: SectionModifiedDelegate?
    private let inputCellIdentifier = "inputJunctionCell"
    private let displayCellIdentifier = "junctionCell"
    private var delegateProxy: UITextFieldDelegateProxy?
    private var defaultValue: MultipleChoiceOption<T>?
    private var multiSelect: Bool
    
    public init(possibleValues: [MultipleChoiceOption<T>], enableCustom: Bool, name: String, key: String, isMultiSelect: Bool) {
        self.possibleValues = possibleValues
        self.enableCustom = enableCustom
        self.name = name
        self.key = key
        self.multiSelect = isMultiSelect
        
        let initialValue = possibleValues.filter({ $0.isInitialValue }).first
        
        self.defaultValue = initialValue
        
        for value in possibleValues {
            rows.append(StringSetting(placeholder: nil, defaultValue: String(value.value), key: key, title: nil))
        }
        
        if enableCustom {
            rows.append(StringSetting(placeholder: nil, defaultValue: "Custom Option", key: "\(key)_customOption", title: "Custom Option"))
            
            if let customOptions = JunctionKeeper.sharedInstance.getValueWithKey("\(key)_customOption") as? [T] {
                for option in customOptions {
                    let newMultipleSelectionObject = MultipleChoiceOption(value: option, isInitialValue: false)
                    self.possibleValues.append(newMultipleSelectionObject)
                    rows.append(StringSetting(placeholder: nil, defaultValue: String(option), key: key, title: nil))
                }
            }
        }
        
        getCheckmarkIndexes()
        
        if let defaultValue = self.defaultValue {
            if multiSelect {
                JunctionKeeper.sharedInstance.addValueToArray(key, value: defaultValue.value as! AnyObject)
            } else {
                JunctionKeeper.sharedInstance.addValueForKey(key, value: defaultValue.value as! AnyObject)
            }
            sectionDelegate?.editsMade!()
        }
    }
    
    private func getCheckmarkIndexes() {
        if multiSelect {
            
            if let selectedOptions = JunctionKeeper.sharedInstance.getValueWithKey(key) as? [T] {
                
                for option in selectedOptions {
                    let index = possibleValues.indexOf { object -> Bool in
                        return (object as AnyObject).isEqual(option as? AnyObject)
                    }
                    
                    if index != nil {
                        self.selectedOptions?.append(index!)
                    }
                }
            }
        } else {
            if let selectedOption = JunctionKeeper.sharedInstance.getValueWithKey(key) as? T {
                self.selectedOption = possibleValues.indexOf { object -> Bool in
                    return (object as AnyObject).isEqual(selectedOption as? AnyObject)
                }
            }
        }
    }
    
    public func registerCells(tableView: UITableView) {
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: displayCellIdentifier)
        tableView.registerClass(InputTableViewCell.self, forCellReuseIdentifier: inputCellIdentifier)
    }
    
    public func numberOfRows() -> Int {
        if enableCustom {
            return possibleValues.count + 1
        } else {
            return possibleValues.count
        }
    }
    
    public func tableViewCellIdentifier(row: Int) -> String {
        if enableCustom && rows.count - 1 == row {
            return inputCellIdentifier
        } else {
            return displayCellIdentifier
        }
    }
    
    public func configureCell(cell: UITableViewCell, row: Int) {
        
        if cell.reuseIdentifier == inputCellIdentifier {
            delegateProxy = UITextFieldDelegateProxy { [weak self] (textField) in
                textField.resignFirstResponder()
                
                guard let text = textField.text where text != "" else {
                    return false
                }
                
                textField.text = nil
                
                self?.addCustomValue(text)
                self?.sectionDelegate?.editsMade!()
                
                return false
            }
            
            let inputCell = cell as! InputTableViewCell
            inputCell.textField.delegate = delegateProxy
        }
        
        if row < possibleValues.count {
            cell.textLabel!.text = String(possibleValues[row].value)
            
            var checkAgainst: Int?
            
            if let selectedOption = selectedOption {
                checkAgainst = selectedOption
            } else if let defaultValue = defaultValue {
                checkAgainst = possibleValues.indexOf { object -> Bool in
                    return (object as AnyObject).isEqual(defaultValue)
                }
            }
            
            if multiSelect {
                
                if let options = selectedOptions {
                    
                    if options.contains(row) {
                        cell.accessoryType = .Checkmark
                    } else {
                        cell.accessoryType = .None
                    }
                }
            } else {
                if let rowNumber = checkAgainst {
                    if rowNumber == row {
                        cell.accessoryType = .Checkmark
                    } else {
                        cell.accessoryType = .None
                    }
                }
            }
        }
    }
    
    public func store() {
        
        guard let index = selectedOption else {
            return
        }
        
        let selected = possibleValues[index].value
        
        if multiSelect {
            JunctionKeeper.sharedInstance.addValueToArray(key, value: selected as! AnyObject)
        } else {
            JunctionKeeper.sharedInstance.addValueForKey(key, value: selected as! AnyObject)
        }
    }
    
    public func didSelectCell(tableViewCell: UITableViewCell, tableView: UITableView, indexPath: NSIndexPath) {
        rows[indexPath.row].didSelectCell(tableViewCell, tableView: tableView, indexPath: indexPath)
        
        if tableViewCellIdentifier(indexPath.row) == displayCellIdentifier {
            selectedOption = indexPath.row
            store()
            
            configureCell(tableViewCell, row: indexPath.row)
            tableView.reloadData()
        }
    }
    
    internal func addCustomValue(value: String) {
        fatalError("addCustomValue must be overriden by subclasses")
    }
}

private class UITextFieldDelegateProxy: NSObject, UITextFieldDelegate {
    typealias returnActionType = UITextField -> Bool
    
    let returnAction: returnActionType
    
    init(returnAction: returnActionType) {
        self.returnAction = returnAction
    }
    
    @objc func textFieldShouldReturn(textField: UITextField) -> Bool {
        return returnAction(textField)
    }
}
