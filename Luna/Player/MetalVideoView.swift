//
//  MetalVideoView.swift
//  test
//
//  Created by Francesco on 13/03/26.
//

import UIKit
import QuartzCore

final class MetalVideoView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .black
        isOpaque = true
        metalLayer.isOpaque = true
        metalLayer.framebufferOnly = false
        metalLayer.contentsScale = UIScreen.main.scale
    }
}
