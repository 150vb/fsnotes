//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
        
    func fill(note: Note) {
        self.isEditable = true
        self.isRichText = note.isRTF()
        
        let attributedString = createAttributedString(note: note)
        self.textStorage?.setAttributedString(attributedString)
        self.textStorage?.font = UserDefaultsManagement.noteFont
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true
    }
    
    func save(note: Note) -> Bool {
        let fileUrl = note.url
        let fileExtension = fileUrl?.pathExtension
        
        do {
            if (fileExtension == "rtf") {
                let range = NSRange(0..<textStorage!.length)
                let documentAttributes = DocumentAttributes.getDocumentAttributes(fileExtension: fileExtension!)
                let text = try textStorage?.fileWrapper(from: range, documentAttributes: documentAttributes)
                try text?.write(to: fileUrl!, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
            } else {
                try textStorage?.string.write(to: fileUrl!, atomically: false, encoding: String.Encoding.utf8)
            }
            
            return true
        } catch {
            NSLog("Note write error: " + (fileUrl?.path)!)
        }
        
        return false
    }
    
    func clear() {
        textStorage?.mutableString.setString("")
        isEditable = false
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = false
    }
    
    func createAttributedString(note: Note) -> NSAttributedString {
        let url = note.url
        let fileExtension = url?.pathExtension
        let options = DocumentAttributes.getDocumentAttributes(fileExtension: fileExtension!)
        var attributedString = NSAttributedString()
        
        do {
            attributedString = try NSAttributedString(url: url!, options: options, documentAttributes: nil)
        } catch {
            NSLog("No text content found!")
        }
        
        return attributedString
    }
    
    override func mouseDown(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            viewController.makeNote(NSTextField())
        }
        return super.mouseDown(with: event)
    }
}
