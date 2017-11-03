//
//  NSFont+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/26/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension NSFont {
    var isBold: Bool {
        return (Int(fontDescriptor.symbolicTraits.rawValue) == 1026)
    }
    
    var isItalic: Bool {
        return (Int(fontDescriptor.symbolicTraits.rawValue) == 1025)
    }
    
    var height:CGFloat {
        let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        let boundingBox = "A".boundingRect(with: constraintRect, options: NSString.DrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedStringKey.font: self], context: nil)
        
        return boundingBox.height
    }
}
