/// Copyright (c) 2018 Thomas Kunschner
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import UIKit

open class ToastView: UILabel {
  
  var overlayView = UIView()
  var backView = UIView()
  var lbl = UILabel()
  
  class var shared: ToastView {
    struct Static {
      static let instance: ToastView = ToastView()
    }
    return Static.instance
  }
  
  func setup(_ view: UIView,txt_msg:String)
  {
    let white = UIColor ( red: 1/255, green: 0/255, blue:0/255, alpha: 0.0 )
    
    backView.frame = CGRect(x: 0, y: 0, width: view.frame.width , height: view.frame.height)
    backView.center = view.center
    backView.backgroundColor = white
    view.addSubview(backView)
    
    overlayView.frame = CGRect(x: 0, y: 0, width: view.frame.width - 60  , height: 50)
    overlayView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height - 100)
    overlayView.backgroundColor = UIColor.black
    overlayView.clipsToBounds = true
    overlayView.layer.cornerRadius = 10
    overlayView.alpha = 0
    
    lbl.frame = CGRect(x: 0, y: 0, width: overlayView.frame.width, height: 50)
    lbl.numberOfLines = 0
    lbl.textColor = UIColor.white
    lbl.center = overlayView.center
    lbl.text = txt_msg
    lbl.textAlignment = .center
    lbl.center = CGPoint(x: overlayView.bounds.width / 2, y: overlayView.bounds.height / 2)
    overlayView.addSubview(lbl)
    
    view.addSubview(overlayView)
  }
  
  open func short(_ view: UIView,txt_msg:String) {
    self.setup(view,txt_msg: txt_msg)
    //Animation
    UIView.animate(withDuration: 1, animations: {
      self.overlayView.alpha = 1
    }) { (true) in
      UIView.animate(withDuration: 1, animations: {
        self.overlayView.alpha = 0
      }) { (true) in
        UIView.animate(withDuration: 1, animations: {
          DispatchQueue.main.async(execute: {
            self.overlayView.alpha = 0
            self.lbl.removeFromSuperview()
            self.overlayView.removeFromSuperview()
            self.backView.removeFromSuperview()
          })
        })
      }
    }
  }
  
  open func long(_ view: UIView,txt_msg:String) {
    self.setup(view,txt_msg: txt_msg)
    //Animation
    UIView.animate(withDuration: 2, animations: {
      self.overlayView.alpha = 1
    }) { (true) in
      UIView.animate(withDuration: 2, animations: {
        self.overlayView.alpha = 0
      }) { (true) in
        UIView.animate(withDuration: 2, animations: {
          DispatchQueue.main.async(execute: {
            self.overlayView.alpha = 0
            self.lbl.removeFromSuperview()
            self.overlayView.removeFromSuperview()
            self.backView.removeFromSuperview()
          })
        })
      }
    }
  }
}
