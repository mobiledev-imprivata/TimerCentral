//
//  BluetoothManager.swift
//  TimerCentral
//
//  Created by Jay Tucker on 5/28/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    
    private let serviceUUID              = CBUUID(string: "D5C677E9-7090-452B-8251-CB3EA027FE4F")
    private let requestCharacteristicUUID  = CBUUID(string: "2B771F92-CBC8-4C69-816B-B844E87E9CD4")
    private let responseCharacteristicUUID = CBUUID(string: "CD565DAE-C38B-42A7-957C-7D2AAE75DD1D")
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    
    var requestCharacteristic: CBCharacteristic!
    var responseCharacteristic: CBCharacteristic!
    
    private var isPoweredOn = false
    private var scanTimer: NSTimer!
    private let timeoutInSecs = 8.0
    
    private var isBusy = false
    
    private var maxRequests = 40
    private var nRequests = 0
    private var nResponses = 0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate:self, queue:nil)
    }
    
    private func nameFromUUID(uuid: CBUUID) -> String {
        switch uuid {
        case serviceUUID: return "service"
        case requestCharacteristicUUID: return "requestCharacteristic"
        case responseCharacteristicUUID: return "responseCharacteristic"
        default: return "unknown"
        }
    }
    
    func go() {
        log("go")
        if isBusy {
            log("busy, ignoring")
            return
        }
        if !isPoweredOn {
            log("not powered on")
            return
        }
        isBusy = true
        nRequests = 0
        nResponses = 0
        startScanForPeripheralWithService(serviceUUID)
    }
    
    private func sendRequest() {
        log("sendRequest")
        let data = "Hello, world!".dataUsingEncoding(NSUTF8StringEncoding)
        peripheral.writeValue(data, forCharacteristic: requestCharacteristic, type: CBCharacteristicWriteType.WithResponse)
    }
    
    private func processResponse(responseData: NSData) {
        let response = NSString(data: responseData, encoding: NSUTF8StringEncoding)!
        nResponses++
        log("received response \(nResponses): \(response)")
    }
    
    private func startScanForPeripheralWithService(uuid: CBUUID) {
        nRequests++
        log("making request \(nRequests)")
        log("startScanForPeripheralWithService \(nameFromUUID(uuid)) \(uuid)")
        centralManager.stopScan()
        peripheral = nil
        requestCharacteristic = nil
        responseCharacteristic = nil
        scanTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutInSecs, target: self, selector: Selector("timeout"), userInfo: nil, repeats: false)
        centralManager.scanForPeripheralsWithServices([uuid], options: nil)
    }
    
    // can't be private because called by timer
    func timeout() {
        log("timed out")
        centralManager.stopScan()
        isBusy = false
    }
    
    private func disconnect() {
        log("disconnect")
        centralManager.cancelPeripheralConnection(peripheral)
        peripheral = nil
        requestCharacteristic = nil
        responseCharacteristic = nil
        isBusy = false
        if nRequests < maxRequests {
            let delay = 100.0
            let restartTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_MSEC)))
            dispatch_after(restartTime, dispatch_get_main_queue()) {
                self.startScanForPeripheralWithService(self.serviceUUID)
            }
        }
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        var caseString: String!
        switch centralManager.state {
        case .Unknown:
            caseString = "Unknown"
        case .Resetting:
            caseString = "Resetting"
        case .Unsupported:
            caseString = "Unsupported"
        case .Unauthorized:
            caseString = "Unauthorized"
        case .PoweredOff:
            caseString = "PoweredOff"
        case .PoweredOn:
            caseString = "PoweredOn"
        default:
            caseString = "WTF"
        }
        log("centralManagerDidUpdateState \(caseString)")
        isPoweredOn = (centralManager.state == .PoweredOn)
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        log("centralManager didDiscoverPeripheral")
        scanTimer.invalidate()
        centralManager.stopScan()
        self.peripheral = peripheral
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        log("centralManager didConnectPeripheral")
        self.peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
}

extension BluetoothManager: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if error == nil {
            log("peripheral didDiscoverServices ok")
        } else {
            log("peripheral didDiscoverServices error \(error.localizedDescription)")
            return
        }
        if peripheral.services.isEmpty {
            log("no services found")
            disconnect()
            return
        }
        for service in peripheral.services {
            log("service \(nameFromUUID(service.UUID))  \(service.UUID)")
            peripheral.discoverCharacteristics(nil, forService: service as! CBService)
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if error == nil {
            log("peripheral didDiscoverCharacteristicsForService \(nameFromUUID(service.UUID)) \(service.UUID) ok")
        } else {
            log("peripheral didDiscoverCharacteristicsForService \(nameFromUUID(service.UUID)) \(service.UUID) error \(error.localizedDescription)")
            return
        }
        for characteristic in service.characteristics {
            let name = nameFromUUID(characteristic.UUID)
            log("characteristic \(name) \(characteristic.UUID)")
            switch characteristic.UUID {
            case requestCharacteristicUUID:
                requestCharacteristic = characteristic as! CBCharacteristic
            case responseCharacteristicUUID:
                responseCharacteristic = characteristic as! CBCharacteristic
            default:
                break
            }
        }
        sendRequest()
    }
    
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if error == nil {
            log("peripheral didWriteValueForCharacteristic ok")
            peripheral.readValueForCharacteristic(responseCharacteristic)
        } else {
            log("peripheral didWriteValueForCharacteristic error \(error.localizedDescription)")
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if error == nil {
            let name = nameFromUUID(characteristic.UUID)
            log("peripheral didUpdateValueForCharacteristic \(name) ok")
            processResponse(characteristic.value)
        } else {
            log("peripheral didUpdateValueForCharacteristic error \(error.localizedDescription)")
        }
        disconnect()
    }
    
}