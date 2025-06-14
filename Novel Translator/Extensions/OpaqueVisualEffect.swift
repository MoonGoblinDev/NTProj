//
//  OpaqueVisualEffect.swift
//  Novel Translator
//
//  Created by Bregas Satria Wicaksono on 13/06/25.
//

import SwiftUI
 
struct OpaqueVisualEffect: NSViewRepresentable {
 
    func makeNSView(context: Self.Context) -> NSView {
        let test = NSVisualEffectView()
        test.state = NSVisualEffectView.State.active  // this is this state which says transparent all of the time
        return test }
 
    func updateNSView(_ nsView: NSView, context: Context) { }
}
 
