//
//  ViewController.swift
//  TimerCentral
//
//  Created by Jay Tucker on 5/28/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var bluetoothManager: BluetoothManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        bluetoothManager = BluetoothManager()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onGo(sender: AnyObject) {
        log("onGo")
        bluetoothManager.go()
    }

}

