//
//  ViewController.swift
//  colorTestClient_iOS
//
//  Created by iMola on 2018. 7. 27..
//  Copyright © 2018년 KGMedia. All rights reserved.
//

import UIKit
import SwiftSocket

class ViewController: UIViewController, UITextFieldDelegate {
    //MARK: Properties
    @IBOutlet weak var ipTextField: UITextField!
    @IBOutlet weak var textView: UITextView!
    
    let port: Int32 = 80
    var client: TCPClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Handle the text field's user input through delegate callbacks.
        ipTextField.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueNext" {
            if let destinationVC = segue.destination as? subViewController {
                destinationVC.client = client
            }
        }
    }
    
    //MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let host = textField.text {
            textView.text = textView.text.appending("\n\(host)")
            client = TCPClient(address: host, port: port)
        } else {
            textView.text = textView.text.appending("\nYou have to input IP address")
        }
    }
    
    //MARK: Actions
    @IBAction func connect(_ sender: UIButton) {
        guard let client = client else { return }
        
        switch client.connect(timeout: 10) {
        case .success:
            textView.text = textView.text.appending("\nConnected to host \(client.address)")
            self.performSegue(withIdentifier: "segueNext", sender: self)
        case .failure(let error):
            textView.text = textView.text.appending("\n\(String(describing: error))")
        }
    }
}

//MARK: Sub view controller
class subViewController: UIViewController {
    //MARK: Properties
    var client: TCPClient? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        UIScreen.main.brightness = 0.5
        changeBackgroundColor(R: 255, G: 255, B: 255, colorSpaceSelect: 1, client: client)
        DispatchQueue(label: "wait signal").async {
            self.waitSignal(client: self.client)
        }
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return true
    }
    
    //MARK: Function
    func waitSignal(client: TCPClient?) {
        guard let client = client else { return }
        
        var upperBound: CGFloat = 1
        var lowerBound: CGFloat = 0
        
        while true {
            sleep(2)
            let rawData = client.read(1024*10)
            if let data = rawData {
                if data[0] == 0 {
                    (upperBound, lowerBound) =
                        brightnessAdjust(upOrDown: data[1],
                                         upperBound: upperBound,
                                         lowerBound: lowerBound,
                                         client: client)
                } else if data[0] == 1 {
                    DispatchQueue.main.async {
                        self.changeBackgroundColor(R: data[1], G: data[2], B: data[3], colorSpaceSelect: data[4], client: client)
                    }
                } else if data[0] == 2 {
                    upperBound = 1
                    lowerBound = 0
                    
                    DispatchQueue.main.async {
                        UIScreen.main.brightness = 0.5
                        self.changeBackgroundColor(R: 255, G: 255, B: 255, colorSpaceSelect: 1, client: client)
                    }
                }
            }
        }
    }
    
    func changeBackgroundColor(R: UInt8, G: UInt8, B: UInt8, colorSpaceSelect: UInt8, client: TCPClient?) {
        let red: CGFloat = CGFloat(Double(R) / 255)
        let green: CGFloat = CGFloat(Double(G) / 255)
        let blue: CGFloat = CGFloat(Double(B) / 255)
        
        if colorSpaceSelect == 1 { // sRGB
            let color: UIColor = UIColor.init(red: red, green: green, blue: blue, alpha: 1)
            self.view.backgroundColor = color
        } else if colorSpaceSelect == 0 { // Display P3
            let color: UIColor = UIColor.init(displayP3Red: red, green: green, blue: blue, alpha: 1)
            self.view.backgroundColor = color
        } else if colorSpaceSelect == 3 { // ACESCG Linear
            let cSpace = CGColorSpace(name: CGColorSpace.acescgLinear)!
            let comps: [CGFloat] = [red, green, blue, 1.0]
            let color_cg = CGColor(colorSpace: cSpace, components: comps)!
            let color: UIColor = UIColor.init(cgColor: color_cg)
            self.view.backgroundColor = color
        } else if colorSpaceSelect == 2 { // AdobeRGB
            let cSpace = CGColorSpace(name: CGColorSpace.adobeRGB1998)!
            let comps: [CGFloat] = [red, green, blue, 1.0]
            let color_cg = CGColor(colorSpace: cSpace, components: comps)!
            let color: UIColor = UIColor.init(cgColor: color_cg)
            self.view.backgroundColor = color
        } else if colorSpaceSelect == 4 { // Rec2020
            let cSpace = CGColorSpace(name: CGColorSpace.itur_2020)!
            let comps: [CGFloat] = [red, green, blue, 1.0]
            let color_cg = CGColor(colorSpace: cSpace, components: comps)!
            let color: UIColor = UIColor.init(cgColor: color_cg)
            self.view.backgroundColor = color
        }
        
        guard let client = client else {
            return
        }
        
        sleep(1)
        _ = client.send(data: [1]) // need to change for error check
    }
    
    func brightnessAdjust(upOrDown: UInt8,
                          upperBound: CGFloat,
                          lowerBound: CGFloat,
                          client: TCPClient?)
        -> (upper: CGFloat,lower: CGFloat) {
            // print("Enter change brightness\n")
            
            guard let client = client else { return (0, 0) }
            var upper: CGFloat = 0
            var lower: CGFloat = 0
            
            if upOrDown == 0 {
                print(upperBound)
                print(lowerBound)
                upper = UIScreen.main.brightness
                lower = lowerBound
                print(upper)
                print(lower)
                print("down\n")
            } else if upOrDown == 1 {
                print(upperBound)
                print(lowerBound)
                upper = upperBound
                lower = UIScreen.main.brightness
                print(upper)
                print(lower)
                print("up\n")
            } else if upOrDown == 2 {
                upper = 1
                lower = 1
                print("brightness is now max")
            } else if upOrDown == 3 {
                upper = 0
                lower = 0
                print("brightness is now min")
            }
            
            DispatchQueue.main.async {
                UIScreen.main.brightness = (upper + lower) / 2
            }
            
            sleep(1)
            
            _ = client.send(data: [1]) // need to change for error check
            
            return (upper, lower)
    }
}
