//
//  Service.swift
//  csc2228
//
//  Created by Yolanda He on 2017-10-10.
//  Copyright © 2017 csc2228. All rights reserved.
//

import Foundation
import CoreMotion
import CoreLocation
import AWSDynamoDB

class Service {
    
    var samplingAccTimer: Timer!
    var samplingLocTimer: Timer!
    var uploadTimer: Timer!
    var action:String!
    var accQueue=[[AWSDynamoDBWriteRequest]]()
    var locQueue=[[AWSDynamoDBWriteRequest]]()
    var recordAcc=[AWSDynamoDBWriteRequest]()
    var recordLocation=[AWSDynamoDBWriteRequest]()
    var db:AWSDynamoDB!
    var updateInput:AWSDynamoDBUpdateItemInput!
    
    var motionManager: CMMotionManager!
    var locationManager:  CLLocationManager!
    func newTimerTask(action: String!) {
        print("Creating new timer "+action)
        self.action=action
        // Clean the existing timer first. That means, ensure the running timer will be clean out before a new task.
        clearTimers()
        
        //initialize the managers
        initManagers()
        
        //initialize AWS DynamoDB
        initDynamoDB()
        
        // Set up the timer to upload local dataset, and to sample data.
        uploadTimer = Timer.scheduledTimer(timeInterval: Constants.INTERVAL_UPLOAD, target: self, selector: #selector(sendExistingData), userInfo: nil, repeats: true)
        samplingAccTimer = Timer.scheduledTimer(timeInterval: Constants.INTERVAL_SAMPLING_ACCELEROMETER, target: self, selector: #selector(sampleAccelerometer), userInfo: nil, repeats: true)
        samplingLocTimer = Timer.scheduledTimer(timeInterval: Constants.INTERVAL_SAMPLING_LOCATION, target: self, selector: #selector(sampleLocation), userInfo: nil, repeats: true)
        
        

    }
    
    func initDynamoDB(){
        db = AWSDynamoDB.default()
    }
    
    
    
    func initManagers(){
        
        self.motionManager = CMMotionManager()
        self.motionManager.accelerometerUpdateInterval=Constants.INTERVAL_SAMPLING_ACCELEROMETER/2.0
        self.motionManager.startAccelerometerUpdates()
        
        
        if(CLLocationManager.locationServicesEnabled()){
            locationManager=CLLocationManager()
            locationManager.requestAlwaysAuthorization()
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        else{
            print("location service unavailable")
        }
        
    }
    
    func cleanAll(){
        clearManagers()
        clearTimers()
        cleanCache()
    }
    
    func clearManagers(){
        guard let _=motionManager else {
            return
        }
        
        motionManager.stopAccelerometerUpdates()
        guard let _=locationManager else {
            return
        }
        
        locationManager.stopUpdatingLocation()
        
    }
    
    func clearTimers() {
        clearAccTimer()
        clearUploadTimer()
        clearLocTimer()
    }
    
    func clearLocTimer() {
        guard let _=samplingLocTimer else {
            return
        }
        
        print("samplingLocTimer Canceled")
        samplingLocTimer.invalidate()
    }
    func clearAccTimer()  {
        guard let _=samplingAccTimer else {
            return
        }
        
        print("samplingAccTimer Canceled")
        samplingAccTimer.invalidate()
    }
    
    func clearUploadTimer(){
        guard let _=uploadTimer else {
            return
        }
        
        print("uploadTimer Canceled")
        uploadTimer.invalidate()
    }
    
    
    func doesAccExceedMaxQueueSize(){
        if recordAcc.count == 25 {
            accQueue.append(recordAcc)
            recordAcc.removeAll()
        }
        

    
    }
    
    func doesLocExceedMaxQueueSize(){
        if recordLocation.count == 25 {
            locQueue.append(recordLocation)
            recordLocation.removeAll()
        }
    }
 
    
    
    @objc func sampleLocation(){
        
        doesLocExceedMaxQueueSize()
        
        let location = locationManager.location
        
        let latitude = AWSDynamoDBAttributeValue()
        latitude?.s = String(format:"%.8f",location!.coordinate.latitude)
        
        let longtitude = AWSDynamoDBAttributeValue()
        longtitude?.s = String(format:"%.8f",location!.coordinate.longitude)
        
        let time = AWSDynamoDBAttributeValue()
        time?.s = String(format:"%@",location!.timestamp.description)
        
        let currentAction = AWSDynamoDBAttributeValue()
        currentAction?.s=self.action
        
        let write_request = AWSDynamoDBWriteRequest()
        write_request?.putRequest=AWSDynamoDBPutRequest()
        
        write_request?.putRequest?.item = [Constants.COLUMN_LATITUDE:latitude!, Constants.COLUMN_LONGTITUDE:longtitude!, Constants.COLUMN_TIMESTAMP:time!, Constants.COLUMN_ACTION:currentAction!]
        
        recordLocation.append(write_request!)
        
        
        
    }
    
    @objc func sampleAccelerometer(){
        
//        let data = self.motionManager.accelerometerData
//        let x = NSString(format:"%.6f",data!.acceleration.x)
//        let y = NSString(format:"%.6f",data!.acceleration.y)
//        let z = NSString(format:"%.6f",data!.acceleration.z)
//        let time="\(data!.timestamp)"
//        let sample=NSString(format:"{x:%@, y:%@, z:%@, timestamp:%@, action:%@}",x,y,z,time,action)
//        recordAcc.append(sample)
        
        
        doesAccExceedMaxQueueSize()
        
        let data = self.motionManager.accelerometerData
        
        let x = AWSDynamoDBAttributeValue()
        x?.s = String(format:"%.6f",data!.acceleration.x)
        
        let y = AWSDynamoDBAttributeValue()
        y?.s = String(format:"%.6f",data!.acceleration.y)
        
        let z = AWSDynamoDBAttributeValue()
        z?.s = String(format:"%.6f",data!.acceleration.z)
        
        let time = AWSDynamoDBAttributeValue()
        time?.s = "\(data!.timestamp)"
        
        let currentAction = AWSDynamoDBAttributeValue()
        currentAction?.s=self.action
        
        let write_request = AWSDynamoDBWriteRequest()
        write_request?.putRequest=AWSDynamoDBPutRequest()
        
        write_request?.putRequest?.item = [Constants.COLUMN_X:x!, Constants.COLUMN_Y:y!, Constants.COLUMN_Z:z!, Constants.COLUMN_TIMESTAMP:time!, Constants.COLUMN_ACTION:currentAction!]
        
        recordAcc.append(write_request!)
        
        
    }
    

     @objc
    func sendExistingData()  {

        locQueue.append(recordLocation)
        accQueue.append(recordAcc)
        
        for batch in locQueue {
            upload(array:batch, table:Constants.TABLE_LOC)
        }
        
        for batch in accQueue {
            upload(array:batch, table:Constants.TABLE_ACC)
        }

        
       
    }
    
    func upload(array:[AWSDynamoDBWriteRequest]!, table:String!) {
        let batchWriteItemInput = AWSDynamoDBBatchWriteItemInput()
        batchWriteItemInput?.requestItems = [ table:array]
        
        db.batchWriteItem(batchWriteItemInput!).continueWith { (task:AWSTask<AWSDynamoDBBatchWriteItemOutput>) -> Any? in
            if let error = task.error as? NSError {
                var icon = "🌎"
                if table == Constants.TABLE_ACC {
                    icon = "❤️"
                }
                print("The request failed. Error: \(error) " + icon)
                return nil
            }
            
            print("I have a feeling that it succeded 🐱")
            return nil
        }
    }
    
    func cleanCache(){
        recordLocation.removeAll()
        recordAcc.removeAll()
    }
    
    
}

