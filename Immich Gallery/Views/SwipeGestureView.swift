//
//  SwipeGestureView.swift
//  Immich Gallery
//
//  Created by mensadi-labs Kumar on 2025-06-29.
//

import SwiftUI
import UIKit

// UIKit wrapper for tvOS directional pad navigation using UITapGestureRecognizer
struct SwipeGestureView: UIViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        
        print("SwipeGestureView: Creating UIView with user interaction enabled")
        
        // Try a simpler approach - just use basic tap gestures for all directions
        let leftGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLeft))
        leftGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        view.addGestureRecognizer(leftGesture)
        print("SwipeGestureView: Added LEFT gesture recognizer")
        
        let rightGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRight))
        rightGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        view.addGestureRecognizer(rightGesture)
        print("SwipeGestureView: Added RIGHT gesture recognizer")
        
        // Add swipe gestures for touchpad
        let leftSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLeft))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        print("SwipeGestureView: Added LEFT swipe gesture recognizer")
        
        let rightSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRight))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        print("SwipeGestureView: Added RIGHT swipe gesture recognizer")
        
        // Test tap gesture
        let testTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.testTap))
        view.addGestureRecognizer(testTap)
        print("SwipeGestureView: Added test tap gesture recognizer")
        
        print("SwipeGestureView: All gesture recognizers added for tvOS navigation")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }
    
    class Coordinator: NSObject {
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void
        
        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
            print("SwipeGestureView.Coordinator: Initialized with navigation callbacks")
        }
        
        @objc func handleLeft(_ gesture: UIGestureRecognizer) {
            print("SwipeGestureView: LEFT gesture detected (type: \(type(of: gesture))) - navigating to previous photo")
            onSwipeRight()
        }
        
        @objc func handleRight(_ gesture: UIGestureRecognizer) {
            print("SwipeGestureView: RIGHT gesture detected (type: \(type(of: gesture))) - navigating to next photo")
            onSwipeLeft()
        }
        
        @objc func testTap(_ gesture: UITapGestureRecognizer) {
            print("SwipeGestureView: Test tap detected - view is receiving touch events!")
        }
    }
} 