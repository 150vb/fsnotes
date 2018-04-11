//
//  SidebarProjectView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/9/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarProjectView: NSOutlineView, NSOutlineViewDelegate, NSOutlineViewDataSource {
    var sidebarItems: [SidebarItem]? = nil
    var viewDelegate: ViewController? = nil
    
    private var storage = Storage.sharedInstance()
        
    override func draw(_ dirtyRect: NSRect) {
        delegate = self
        dataSource = self
        super.draw(dirtyRect)
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let sidebar = sidebarItems else { return 0 }
        
        if item == nil {
            return sidebar.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let si = item as? SidebarItem, si.type == .Label {
            return 35
        }
        return 25
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let sidebar = sidebarItems else { return "" }
        
        if item == nil {
            return sidebar[index]
        }
        
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCellView
        if let si = item as? SidebarItem {
            cell.textField?.stringValue = si.name
            
            switch si.type {
            case .All:
                if let image = NSImage.init(named: .homeTemplate) {
                    cell.icon.image = image
                    cell.icon.isHidden = false
                    cell.label.frame.origin.x = 25
                }
                
            case .Trash:
                if let image = NSImage.init(named: .trashFull) {
                    cell.icon.image = image
                    cell.icon.isHidden = false
                    cell.label.frame.origin.x = 25
                }
                
            case .Label:
                cell.icon.isHidden = true
                cell.label.frame.origin.x = 5
                
            case .Category:
                cell.icon.image = NSImage(imageLiteralResourceName: "repository.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            default:
                break
            }
        }
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let x = item as? SidebarItem, x.type == .Label {
            return true
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let x = item as? SidebarItem else {
            return false
        }
        
        if x.type == .Label && x.name == "Library" {
            return false
        }
        
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SidebarTableRowView(frame: NSZeroRect)
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let view = notification.object as? NSOutlineView {
            guard let sidebar = sidebarItems, let vd = viewDelegate else { return }
            vd.editArea.clear()
                        
            let i = view.selectedRow
            if sidebar.indices.contains(i) {
                vd.updateTable() {}
            }
        }
    }

    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
        }
    }
    
    @IBAction func revealInFinder(_ sender: Any) {
        guard let si = sidebarItems, si.indices.contains(selectedRow) else { return }
        
        let sidebarItem = si[selectedRow]
        guard let p = sidebarItem.project else { return }
        
       NSWorkspace.shared.activateFileViewerSelecting([p.url])
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        guard let si = sidebarItems, si.indices.contains(selectedRow) else { return }
        
        let sidebarItem = si[selectedRow]
        guard
            sidebarItem.type == .Category,
            let projectRow = rowView(atRow: selectedRow, makeIfNecessary: false),
            let cell = projectRow.view(atColumn: 0) as? SidebarCellView else { return }
        
        cell.label.isEditable = true
        cell.label.becomeFirstResponder()
    }
    
    @IBAction func deleteMenu(_ sender: Any) {
        guard let si = sidebarItems, si.indices.contains(selectedRow) else { return }
        
        let sidebarItem = si[selectedRow]
        guard let project = sidebarItem.project else { return }
        guard sidebarItem.type == .Category else { return }
        
        if !project.isRoot {
            guard let w = self.superview?.window else {
                return
            }
            
            let alert = NSAlert.init()
            alert.messageText = "Are you sure you want to remove project \"\(project.label)\" and all files inside?"
            alert.informativeText = "This action cannot be undone."
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: w) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    try? FileManager.default.trashItem(at: project.url, resultingItemURL: nil)
                    self.removeProject(project: project)
                }
            }
            return
        }
        
        SandboxBookmark().removeBy(project.url)
        removeProject(project: project)
    }
    
    private func removeProject(project: Project) {
        self.storage.removeBy(project: project)
        
        self.viewDelegate?.restartFileWatcher()
        self.viewDelegate?.cleanSearchAndEditArea()
        
        self.sidebarItems = Sidebar().getList()
        self.reloadData()
    }
}
