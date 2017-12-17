//
//  ABAppUpdateManager.swift
//  Naher
//
//  Created by Abhisek on 21/07/17.
//  Copyright © 2017 A.bhisek All rights reserved.
//

import UIKit

class ABAppUpdateManager: NSObject {
  
  static let sharedUpdateManager = ABAppUpdateManager()
  
  fileprivate let appUpdationFirstAlert = "appUpdationFirstAlert"
  fileprivate let lastUpdateDetails = "lastUpdateDetails"
  fileprivate let updateDate = "updateDate"
  fileprivate let alertCount = "alertCount"
  fileprivate var isUpdationAlertVisible = false
  fileprivate var defaultCompulsoryUpdationTimePeriod:Double = 10
  fileprivate let eachDayAlertThreshold = 1
  
  var alertTitle = "New Version"
  var isAvailableOnStore = "is available on the AppStore."
  var alertUpdateButtonTitle = "Update"
  var alertCancelButtonTitle = "Not Now"
  
  
  /*
   *  isUpdateAvailable
   *
   *  Discussion:
   *      Checks whether update is available for the app or not and displays alert as per user choice
   *
   *  Params:
   *      willShowALert: Whether an alert will be shown if there is an update is available or not
   *
   *      appUdationCompulsoryTimePeriod: If the alert will be a compulsory one, then this argument
   *      takes number of days as double value.
   *      Default value is 10 days
   *
   */
  
  func isUpdateAvailable(willShowALert: Bool,appUdationCompulsoryTimePeriod: Double?, completion: @escaping (_ isUpdateAvailable:Bool, _ latestVersion: String?, _ iTunesUrl: String?)->()) {
    
    guard
      let info = Bundle.main.infoDictionary,
      let identifier = info["CFBundleIdentifier"] as? String,
      let currentVersion = info["CFBundleShortVersionString"]
      else {
        completion(false, nil, nil)
        return
    }
    
    // For testing, uncomment: let id = "com.yelp.yelpiphone" and replace identifier with id below
    //        let identifier = "com.yelp.yelpiphone"
    let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(identifier)")
    
    DispatchQueue.global(qos: .background).async {
      
      guard let data = try? Data(contentsOf: url!) else {
        return
      }
      
      let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
      
      if let resultsCount = json??["resultCount"] as? Int {
        if resultsCount == 0 {
          return
        }
      }
      
      guard let results = json??["results"] as? [[String: Any]] else {
        print("App update results is nil")
        return
      }
      
      let appDetails = results.first
      let appItunesUrl: String = (appDetails?["trackViewUrl"] as! String).replacingOccurrences(of: "&uo=4", with: "")
      
      let latestVersion = appDetails?["version"] as? NSString
      if latestVersion?.compare(currentVersion as! String, options: .numeric) == .orderedDescending{
        
        if willShowALert {
          self.showAlert(latestVersion: latestVersion!, appItunesUrl: appItunesUrl, appUdationCompulsoryTimePeriod: appUdationCompulsoryTimePeriod)
        }
        
        completion(true, latestVersion! as String, appItunesUrl)
      } else {
        self.removeAppUpdationFirstAlertDate()
        completion(false, nil, nil)
      }
      
    }
    
  }
  
  fileprivate func showAlert(latestVersion: NSString,appItunesUrl : String,appUdationCompulsoryTimePeriod: Double?) {
    
    let message = "Version " + (latestVersion as String) + " " + isAvailableOnStore
    
    if let appFirstUpdationAlertDate = self.getAppUpdationFirstAlertDate() as? Date {
      
      let compulsoryTimePeriod:Double = {if let timePeriod = appUdationCompulsoryTimePeriod {
        return timePeriod
      } else {
        //default
        return defaultCompulsoryUpdationTimePeriod
        }
      }()
      
      
      if Date().timeIntervalSince(appFirstUpdationAlertDate) >= compulsoryTimePeriod*3600*24 {
        
        self.saveLastUpdateDetails(forDate: Date())
        self.isUpdationAlertVisible = true
        DispatchQueue.main.async {
          //Show compulsory alert with a single updtion button
        }
        
        
      } else { //If the time is < Compulsory period
        
        self.saveLastUpdateDetails(forDate: Date())
        if hasCrossedEachDayThreshold() {
          return
        }
        
        self.isUpdationAlertVisible = true
        DispatchQueue.main.async {
          //Show compulsory alert with an updation and later button
        }
        
      }
      
      
    } else {
      
      self.saveAppUpdationFirstAlertDate()
      self.saveLastUpdateDetails(forDate: Date())
      self.isUpdationAlertVisible = true
      DispatchQueue.main.async {
       //Show compulsory alert with an updation and later button
      }
      
    }
    
  }
  
  //Function that if the alert that will be shown is the first for the day
  func hasCrossedEachDayThreshold() -> Bool {
    
    guard let updationDetails = getLastUpdateDetails() else {
      return false
    }
    
    let alertCount = updationDetails[self.alertCount] as! Int
    if alertCount > Int(defaultCompulsoryUpdationTimePeriod) {
      return true
    }
    return false
    
  }
  
}

extension ABAppUpdateManager {
  
  func saveLastUpdateDetails(forDate date: Date) {
    
    let userDefault = UserDefaults.standard
    var metaData: [String: Any] = [String: Any]()
    
    func saveInitialData() {
      metaData[self.updateDate] = Date()
      metaData[self.alertCount] = 1
    }
    
    guard let updationDetails = getLastUpdateDetails() else {
      saveInitialData()
      return
    }
    
    let updatedDate = updationDetails[self.updateDate] as! Date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyy"
    if dateFormatter.string(from: Date()) != dateFormatter.string(from: updatedDate) {
      saveInitialData()
      return
    }
    
    var alertCount = updationDetails[self.alertCount] as! Int
    
    alertCount = alertCount + 1
    metaData[self.updateDate] = updatedDate
    metaData[self.alertCount] = alertCount
    
    userDefault.set(metaData, forKey: lastUpdateDetails)
    
  }
  
  func removeLastUpdateDetails() {
    let userDefaults = UserDefaults.standard
    userDefaults.removeObject(forKey: lastUpdateDetails)
  }
  
  func getLastUpdateDetails() -> [String: Any]? {
    let userDefaults = UserDefaults.standard
    return userDefaults.object(forKey: lastUpdateDetails) as? [String : AnyObject]
  }
  
}

//MARK: App Updation First alert functions
extension ABAppUpdateManager {
  func saveAppUpdationFirstAlertDate() {
    let userDefaults = UserDefaults.standard
    userDefaults.set(Date(), forKey: appUpdationFirstAlert)
  }
  
  func removeAppUpdationFirstAlertDate() {
    let userDefaults = UserDefaults.standard
    userDefaults.removeObject(forKey: appUpdationFirstAlert)
  }
  
  //This is the date of the first alert shown from the time app has been updated.
  //Necessary to calculate the compulsory time period
  func getAppUpdationFirstAlertDate() -> Any? {
    let userDefaults = UserDefaults.standard
    return userDefaults.object(forKey: appUpdationFirstAlert)
  }
}
