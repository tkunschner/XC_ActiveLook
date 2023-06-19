/**
 * Copyright (c) 2020 Thomas Kunschner
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth
import Foundation

/*
 * BLE Identifiers
 */

/* USEE */
// let useeIdentifierUUID = CBUUID(string: "66897807-B180-EB6F-65FD-70BFF0EACCE3")
let nordicUARTServiceCBUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
let nordicUARTCharacteristCBUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let nordicUARTCharacteristNtfyCBUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
var nordicDisplayWrite: CBCharacteristic!
var useeButtonPress = UInt(0)

let bytes : [UInt8] = [ 0x01, 0x06, 0x80, 0x53, 0x50, 0x4F, 0x52, 0x54 ]
let data = Data(bytes:bytes)
//let speed : [UInt8] = [ 0x01, 0x06, 0x40, 0x01, 0xF4, 0x49, 0x00, 0x64 ]
let speed : [UInt8] = [ 0x01, 0x07, 0x40, 0x00, 0xC8, 0x65, 0x01, 0x00, 0x17 ]
//let speed : [UInt8] = [ 0x01, 0x07, 0x65, 0x01, 0x00, 0x32, 0x40, 0x00, 0x4F]

// USEE HUD byte vectors
var speedvarioupmessage : [UInt8] = [ 0x01, 0x07, 0x65, 0x18, 0xFF, 0xFF, 0x40, 0x00, 0x00]
var speedvariodwnmessage : [UInt8] = [ 0x01, 0x07, 0x65, 0x1A, 0xFF, 0xFF, 0x40, 0x00, 0x00]
var heightvarioupmesg : [UInt8] = [ 0x01, 0x07, 0x65, 0x18, 0xFF, 0xFF, 0x46, 0x00, 0xFF]
var heightvariodwnmsg : [UInt8] = [ 0x01, 0x07, 0x65, 0x1A, 0xFF, 0xFF, 0x46, 0x00, 0xFF]
var heightgrdspeedmesg : [UInt8] = [ 0x01, 0x06, 0x40, 0x00, 0x00, 0x46, 0x00, 0xFF]
var data1 = Data(bytes:speed)

/* XC Tracer II, Maxx */
// let xctracerIdentifierUUID = CBUUID(string: "CC99D86B-79F6-49DE-9285-3253D5E5C6CD")
let flightDataServiceCBUUID = CBUUID(string: "0xFFE0")
let flightDataCharacteristCBUUID = CBUUID(string: "0xFFE1")

/*
 * Global Vars
 */
struct MyVariables {
  static var rebuildBLEStr = ""
  static var xctrcFlightData: [String] = []
  static var press = UInt(0)
}

/*
 * UserDefaults
 */
let defaults = UserDefaults.standard

class HRMViewController: UIViewController {

  @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!
  @IBOutlet weak var altValueLabel: UILabel!
  @IBOutlet weak var timeValueLabel: UILabel!
  @IBOutlet weak var useeConnectionStatusView: UIView!
  @IBOutlet weak var xctrcConnectionStatusView: UIView!
    
  //Buttons
  @IBOutlet weak var disconnectBLEDevices: UIButton!
    
  // define our scanning interval times
  let timerPauseInterval:TimeInterval = 10.0
  let timerScanInterval:TimeInterval = 2.0
  var keepScanning = false
  
  // Core Bluetooth properties
  var centralManager: CBCentralManager!
  var flightDataPeripheral: CBPeripheral!
  var displayPeripheral: CBPeripheral!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view, typically from a nib.
    
    // initially, we're scanning and not connected
    
    // Make the digits monospaces to avoid shifting when the numbers change
    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
    altValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: altValueLabel.font!.pointSize, weight: .regular)
    bodySensorLocationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: bodySensorLocationLabel.font!.pointSize, weight: .regular)
    timeValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeValueLabel.font!.pointSize, weight: .regular)
    
    activityIndicatorView.backgroundColor = UIColor.white
    activityIndicatorView.startAnimating()
    useeConnectionStatusView.backgroundColor = UIColor.red
    xctrcConnectionStatusView.backgroundColor = UIColor.red
    
    // hide "Disconnect" Button until peripherals are connected
    self.disconnectBLEDevices.isHidden = true
    
    ToastView.shared.long(self.view, txt_msg: "Discovering XCTracer and USEE ...")
    
    // STEP 1: create a concurrent background queue for the central
    let centralQueue: DispatchQueue = DispatchQueue(label: "com.usee.centralQueueName", attributes: .concurrent)
    
    // STEP 2: create a central to scan for, connect to,
    // manage, and collect data from peripherals
    centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    
    // Make the digits monospaces to avoid shifting when the numbers change
    // heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
    // altValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: altValueLabel.font!.pointSize, weight: .regular)
    // bodySensorLocationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: bodySensorLocationLabel.font!.pointSize, weight: .regular)
    // timeValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeValueLabel.font!.pointSize, weight: .regular)
  }
   
  func onClimbRateReceived(_ climbRate: Float) {
    heartRateLabel.text = String(format: "%.1f", climbRate)
    print("BPM: \(climbRate)")
  }
    
  @IBAction func disconnectBLETdown(_ sender: UIButton) {
        print (">>>> Disconnect Button clicked")
    }
}

extension HRMViewController: CBCentralManagerDelegate {
  
  @objc func pauseScan() {
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    print("*** PAUSING SCAN...")
    _ = Timer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
    centralManager.stopScan()
  }
  
  @objc func resumeScan() {
    if keepScanning {
      // Start scanning again...
      print("*** RESUMING SCAN!")
      _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
      centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
  }
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      #if DEBUG
      print("The state of the BLE Manager is unknown.")
      #endif
    case .resetting:
      #if DEBUG
      print("The BLE Manager is resetting; a state update is pending.")
      #endif
    case .unsupported:
      #if DEBUG
      print("This device does not support Bluetooth Low Energy.")
      #endif
    case .unauthorized:
      #if DEBUG
      print("This app is not authorized to use Bluetooth Low Energy.")
      #endif
    case .poweredOff:
      #if DEBUG
      print("Bluetooth on this device is currently powered off.")
      #endif
    case .poweredOn:
      #if DEBUG
      print("Bluetooth LE is turned on and ready for communication.")
      #endif
      
      keepScanning = true
      _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
      
      // Initiate Scan for USEE and XCtracer Peripherals
      centralManager.scanForPeripherals(withServices: [flightDataServiceCBUUID, nordicUARTServiceCBUUID])
    }
    
  }
  
  // STEP 4.1: discover what peripheral devices OF INTEREST
  // are available for this app to connect to
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    
    print(peripheral)
    
    switch peripheral.name! {
    case "XCTTKU":
      print("XCtracer discovered: \(peripheral.name!)")
      flightDataPeripheral = peripheral
      flightDataPeripheral.delegate = self
      //centralManager.connect(flightDataPeripheral)
    case "XC-Tracer":
      print("XCtracer discovered: \(peripheral.name!)")
      flightDataPeripheral = peripheral
      flightDataPeripheral.delegate = self
      //centralManager.connect(flightDataPeripheral)
    case "USEE":
      print("USEE discovered: \(peripheral.name!)")
      displayPeripheral = peripheral
      displayPeripheral.delegate = self
      //centralManager.connect(displayPeripheral)
    default:
      print("No device discovered")
    }
    
    // stop scanning when xctracer and usee discovered
    if (flightDataPeripheral != nil && displayPeripheral != nil) {
      
      // STEP 5: stop scanning to preserve battery life;
      // re-scan if disconnected
      print("Stopp scanning")
      keepScanning = false
      centralManager.stopScan()
      
      // connect BLE peripherals
      centralManager.connect(flightDataPeripheral)
      centralManager.connect(displayPeripheral)
      
      // stop spinning animation
      DispatchQueue.main.async { () -> Void in
        self.activityIndicatorView.stopAnimating()
        self.disconnectBLEDevices.isHidden = false
      }
    }
  } // END func centralManager(... didDiscover peripheral
  
  // STEP 7: "Invoked when a connection is successfully created with a peripheral."
  // we can only move forward when we know the connection to the peripheral succeeded
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    switch peripheral.name! {
    case "XC-Tracer":
      print("Device connected: \(peripheral.name!)")
      DispatchQueue.main.async { () -> Void in
        ToastView.shared.long(self.view, txt_msg: "XCTracer connected ...")
        self.xctrcConnectionStatusView.backgroundColor = UIColor.green
      }
      flightDataPeripheral.discoverServices(nil)
    case "XCTTKU":
      print("Device connected: \(peripheral.name!)")
      DispatchQueue.main.async { () -> Void in
        ToastView.shared.long(self.view, txt_msg: "XCTracer connected ...")
        self.xctrcConnectionStatusView.backgroundColor = UIColor.green
      }
      flightDataPeripheral.discoverServices(nil)
    case "USEE":
      print("Device connected: \(peripheral.name!)")
      DispatchQueue.main.async { () -> Void in
        ToastView.shared.long(self.view, txt_msg: "USEE connected ...")
        self.useeConnectionStatusView.backgroundColor = UIColor.green
      }
      displayPeripheral.discoverServices(nil)
    default:
      print("Unknown device - not connected: \(peripheral.name!)")
    }
  } // END func centralManager(... didConnect peripheral
  
  // STEP 15: when a peripheral disconnects, take
  // use-case-appropriate action
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
      
    
      // STEP 16: in this use-case, start scanning
      // for the same peripheral or another, as long
      // as they're XCtracers or USEEs, to come back online
      // centralManager?.scanForPeripherals(withServices: [flightDataServiceCBUUID, nordicUARTServiceCBUUID])
      print("Device disconnected: \(peripheral.name!)")
    
      switch peripheral.name! {
      case "XC-Tracer":
      DispatchQueue.main.async { () -> Void in
        self.xctrcConnectionStatusView.backgroundColor = UIColor.red
      }
      centralManager.scanForPeripherals(withServices: [flightDataServiceCBUUID])
      case "XCTTKU":
      DispatchQueue.main.async { () -> Void in
        self.xctrcConnectionStatusView.backgroundColor = UIColor.red
      }
      centralManager.scanForPeripherals(withServices: [flightDataServiceCBUUID])
      case "USEE":
      DispatchQueue.main.async { () -> Void in
        self.useeConnectionStatusView.backgroundColor = UIColor.red
      }
      centralManager.scanForPeripherals(withServices: [nordicUARTServiceCBUUID])
      default:
      print("Unknown device disconnected: \(peripheral.name!)")
      }
    
    //centralManager.scanForPeripherals(withServices: [flightDataServiceCBUUID, nordicUARTServiceCBUUID])
    
    } // END func centralManager(... didDisconnectPeripheral peripheral
}

extension HRMViewController: CBPeripheralDelegate {
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else {return}
    
    for service in services {
      print("SERVICE:")
      print(service)
      print("CHARCTERISTIC:")
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }  // END func peripheral(... didDiscoverServices
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
    guard let characteristics = service.characteristics else { return }
    
    for characteristic in characteristics {
      print(characteristic)
      
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        /* peripheral.readValue(for: characteristic) */
        /* print("READ") */
      }
      
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        
        if characteristic.uuid == flightDataCharacteristCBUUID {
          print("\(characteristic.uuid): NOTIFY XCTRC VALUE")
          peripheral.setNotifyValue(true, for: characteristic)
        }
        
        if characteristic.uuid == nordicUARTCharacteristNtfyCBUUID {
          print("\(characteristic.uuid): NOTIFY UART VALUE")
          peripheral.setNotifyValue(true, for: characteristic)
        }
        
        /* print("NOTIFY") */
      }
      
      if characteristic.properties.contains(.write) {
        print("\(characteristic.uuid): properties contains .write")
        
        if characteristic.uuid == nordicUARTCharacteristCBUUID {
          nordicDisplayWrite = characteristic
          // print("\(nordicDisplayWrite.uuid): WRITE VALUE")
          // peripheral.writeValue(data, for: nordicDisplayWrite, type: CBCharacteristicWriteType.withoutResponse)
        }
        
        /* peripheral.setNotifyValue(true, for: characteristic) */
        /* print("NOTIFY") */
      }
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    var flightDataArr = [String]()
    
    switch characteristic.uuid {
    case nordicUARTCharacteristNtfyCBUUID:
      print("BUTTON PRESS RECEIVED")
      let buttonPressComplete = useeButtonPressed(from: characteristic)
      
    case flightDataCharacteristCBUUID:
      let flightDataComplete = flightData(from: characteristic)
      print("DATA RECEIVED")
      
      if flightDataComplete == 0 {
        print("FUNCTION RETURNED MATCH")
        flightDataArr = MyVariables.rebuildBLEStr.components(separatedBy: ",")
        
        // extract values for climbrate (VSI), ground speed (GS) and altitude (ALT) from xctracer BLE sentence
        
        print("GS:", flightDataArr[11])
        print("VSI:", flightDataArr[13])
        print("ALT:", flightDataArr[10])
        
        // ground speed
        var xtrcspeed = Float(flightDataArr[11])
        // convert to km/h
        xtrcspeed = Float(xtrcspeed! * 3.6)
        let speedrnded = abs((xtrcspeed! * 10).rounded() / 10)
        let gs: UInt16 = UInt16(speedrnded*10)
        
        // climbrate
        let x = Float(flightDataArr[13])
        let y = abs((x! * 10).rounded() / 10)
        let z: UInt16 = UInt16(y*10)
        
        // altitude
        let altxtrc = Float(flightDataArr[10])
        let altrnd = abs((altxtrc! * 100).rounded() / 100)
        let alt: UInt16 = UInt16(altrnd)
        print("ALTINT:", alt)
        
        //print("FLOAT GS:", xtrcspeed)
        //print("Calculated GS:", speedrnded)
        //print("FLOAT climbrate:", x)
        //print("Calculated climbrate:", z)
        
        // move values to USEE display message byte array
        
        switch useeButtonPress {
        case 0:
          if ( x! > Float(0)) {
            speedvarioupmessage[4] = UInt8(z >> 8)
            speedvarioupmessage[5] = UInt8(z & 0x00ff)
            speedvarioupmessage[7] = UInt8(gs >> 8)
            speedvarioupmessage[8] = UInt8(gs & 0x00ff)
            // create byte buffer from array
            data1 = Data(bytes:speedvarioupmessage)
          } else {
            speedvariodwnmessage[4] = UInt8(z >> 8)
            speedvariodwnmessage[5] = UInt8(z & 0x00ff)
            speedvariodwnmessage[7] = UInt8(gs >> 8)
            speedvariodwnmessage[8] = UInt8(gs & 0x00ff)
            // create byte buffer for USEE message from array
            data1 = Data(bytes:speedvariodwnmessage)
          }
        case 1:
          heightgrdspeedmesg[3] = UInt8(gs >> 8)
          heightgrdspeedmesg[4] = UInt8(gs & 0x00ff)
          heightgrdspeedmesg[6] = UInt8(alt >> 8)
          heightgrdspeedmesg[7] = UInt8(alt & 0x00ff)
          // create byte buffer from array
          data1 = Data(bytes:heightgrdspeedmesg)
          
          /*
          if ( x! > Float(0)) {
            heightvarioupmesg[4] = UInt8(z >> 8)
            heightvarioupmesg[5] = UInt8(z & 0x00ff)
            heightvarioupmesg[7] = UInt8(alt >> 8)
            heightvarioupmesg[8] = UInt8(alt & 0x00ff)
            // create byte buffer from array
            data1 = Data(bytes:heightvarioupmesg)
          } else {
            heightvariodwnmsg[4] = UInt8(z >> 8)
            heightvariodwnmsg[5] = UInt8(z & 0x00ff)
            heightvariodwnmsg[7] = UInt8(alt >> 8)
            heightvariodwnmsg[8] = UInt8(alt & 0x00ff)
            // create byte buffer for USEE message from array
            data1 = Data(bytes:heightvariodwnmsg)
          }
        */
          
        default:
          print ("Unknown Button Code \(useeButtonPress)")
        }
        
        
        // print("VARIOHEX:", String(z, radix: 16))
        
        // display values send from xcTracer in app
        DispatchQueue.main.async { () -> Void in
          self.timeValueLabel.text = self.getTimeString()
          self.altValueLabel.text = flightDataArr[10]
          self.bodySensorLocationLabel.text = String(format: "%.1f", xtrcspeed!)
          self.heartRateLabel.text = String(format: "%.1f", x!)
        }
      }
      
      // send to USEE HUD
      if nordicDisplayWrite != nil {
        // print("Write TO DISPLAY")
        displayPeripheral.writeValue(data1, for: nordicDisplayWrite, type: CBCharacteristicWriteType.withoutResponse)
      }
      
    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
  
  private func useeButtonPressed(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData: Data = characteristic.value else { return 2 }
    
    var received: [UInt8] = []
    received = Array(characteristicData)
    
    switch received[2] {
    case 0x01: // right button short pressed
      if useeButtonPress == 2 {
        useeButtonPress = 0
      } else {
        useeButtonPress = 1 - useeButtonPress
      }
    case 0x10: // right button long pressed
      useeButtonPress = 2
    default:
      print ("Unknown Button Code \(received[2])")
    }
    
    /*
    let number = characteristicData.withUnsafeBytes {
      (pointer: UnsafePointer<Int32>) -> Int32 in
      return pointer.pointee
    }
    let correctedNumber: UInt32 = CFSwapInt32(UInt32(number))
    print("BUTTONVALUE:", correctedNumber)
    */
    
    print("USEEBUTTONPRESS:", useeButtonPress)
    print("BUTTONVALUE:", received[0])
    print("BUTTONVALUE:", received[1])
    print("BUTTONVALUE:", received[2])
    
    return 0
  }
  
  private func flightData(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return 2 }
    
    let flightDataArr = characteristicData.toString().components(separatedBy: ",")
    let flightDataType = flightDataArr[0]
    
    if flightDataType == "$XCTRC" {
      // first part of XCTRC sentence
      MyVariables.rebuildBLEStr = characteristicData.toString()
    } else {
      // concatenate next parts
      MyVariables.rebuildBLEStr += characteristicData.toString()
    }
    
    print("REBUILDSTRING:")
    print(MyVariables.rebuildBLEStr)
    
    // check if string is completly reassembled - this is when the checksum is detected
    if MyVariables.rebuildBLEStr.matches("([0-9])*\\*([0-9])*") {
      return 0
    } else {
      return 1
    }
    
    /*
    print("FLIGHTDATARECEIVED:")
    print(characteristicData.toString())
    print("FLIGHTDATAARRAY:")
    print(flightDataArr)
    */
    
    
    /* print("TEST: in func flightData") */
    //return flightDataType
  }
  
  private func toUint(signed: Int) -> UInt {
    
    let unsigned = signed >= 0 ?
      UInt(signed) :
      UInt(signed  - Int.min) + UInt(Int.max) + 1
    
    return unsigned
  }
  
  private func getTimeString() -> String {
    
    let date = Date()
    let calender = Calendar.current
    let components = calender.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
    
    /*
      let year = components.year
      let month = components.month
      let day = components.day
    */
    let hour = components.hour
    let minute = components.minute
    let second = components.second
    
    let time_string = String(hour!)  + ":" + String(minute!)
    
    return time_string
  }
}

extension Data
{
  func toString() -> String
  {
    return String(data: self, encoding: .utf8)!
  }
}

extension String {
  func matches(_ regex: String) -> Bool {
    return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
  }
}
