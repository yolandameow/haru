//
//  Service.swift
//  csc2228
//
//  Created by Wenyang Liu on 2017-10-10.
//  Copyright © 2017 csc2228. All rights reserved.
//

import Foundation
class Service {
    
    var samplingTimer: Timer!
    var uploadTimer: Timer!
    func newTimerTask(action: String)-> Bool {
        print("Creating new timer "+action)
        
        clearTimers()
        sendExistingData()
        
        
        uploadTimer = Timer.scheduledTimer(timeInterval: Constants.INTERVAL_UPLOAD, target: self, selector: #selector(sendExistingData), userInfo: nil, repeats: true)
        
        samplingTimer = Timer.scheduledTimer(timeInterval: Constants.INTERVAL_SAMPLING, target: self, selector: #selector(persistStatus), userInfo: nil, repeats: true)
        
       
        return false
    }
    
    
    func clearTimers() {
        clearSamplingTimer()
        clearUploadTimer()
    }
    
    func clearSamplingTimer()  {
        guard let _=samplingTimer else {
            return
        }
        
        print("samplingTimer Canceled")
        samplingTimer.invalidate()
    }
    
    func clearUploadTimer(){
        guard let _=uploadTimer else {
            return
        }
        
        print("uploadTimer Canceled")
        uploadTimer.invalidate()
    }
    
    
    @objc
    func persistStatus(){
        // TODO: Implement the timer task for sampling data, then store it in either database or file system.
        print("Sampling + 1")
    }
     @objc
    func sendExistingData()  {
        // TODO: Implement the timer task for uploading data
        print("Uploading +1 ")
    }
    
    
}

