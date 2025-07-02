//
//  UIKitFocusable.swift
//  Immich Gallery
//
//  Created by mensadi-labs Kumar on 2025-06-29.
//

import SwiftUI
import UIKit

// A custom UIButton that disables the default tvOS focus effect, based on your suggestion.
class NoFocusEffectButton: UIButton {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // By intentionally not calling super.didUpdateFocus, we prevent the default
        // system focus effect (the white glow/border). The visual feedback (scaling, shadow)
        // is now handled entirely by the SwiftUI content view.
    }
}

// A custom UIView that hosts SwiftUI content and correctly reports its intrinsic size.
// This is the key to solving the layout overlap issue.
class ContentHostingView<Content: View>: UIView {
    private let hostingController: UIHostingController<Content>

    init(content: Content) {
        self.hostingController = UIHostingController(rootView: content)
        super.init(frame: .zero)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // We override intrinsicContentSize to report the SwiftUI view's ideal size.
    override var intrinsicContentSize: CGSize {
        hostingController.sizeThatFits(in: UIView.layoutFittingExpandedSize)
    }

    // When the SwiftUI content updates, we must invalidate our intrinsic size
    // so the layout system knows to re-query it.
    func update(content: Content) {
        hostingController.rootView = content
        invalidateIntrinsicContentSize()
    }
}

// A UIViewRepresentable that wraps our SwiftUI content in the custom UIButton,
// giving us precise control over focus behavior.
struct UIKitFocusable<Content: View>: UIViewRepresentable {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    func makeUIView(context: Context) -> NoFocusEffectButton {
        let button = NoFocusEffectButton(type: .custom)
        
        let hostingView = ContentHostingView(content: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.isUserInteractionEnabled = false // The button handles interaction.
        button.addSubview(hostingView)
        
        // Pin the SwiftUI view to the edges of the button.
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        context.coordinator.contentHostingView = hostingView
        
        // Add the tap action.
        button.addTarget(context.coordinator, action: #selector(Coordinator.performAction), for: .primaryActionTriggered)
        
        return button
    }

    func updateUIView(_ uiView: NoFocusEffectButton, context: Context) {
        // Update the SwiftUI view inside the hosting controller if it changes.
        context.coordinator.contentHostingView?.update(content: content())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        var contentHostingView: ContentHostingView<Content>?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}