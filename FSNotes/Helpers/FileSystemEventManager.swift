//
//  FileSystemEventManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class FileSystemEventManager {
    private var storage: Storage
    private var delegate: ViewController
    private var watcher: FileWatcher?
    private var observedFolders: [String]
    
    init(storage: Storage, delegate: ViewController) {
        self.storage = storage
        self.delegate = delegate
        self.observedFolders = self.storage.getProjectPaths()
    }
    
    public func start() {
        watcher = FileWatcher(self.observedFolders)
        watcher?.callback = { event in
            if UserDataService.instance.fsUpdatesDisabled {
                return
            }
            
            guard let path = event.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return
            }
            
            guard let url = URL(string: "file://" + path) else {
                return
            }
            
            if path.contains(".textbundle") {
                self.handleTextBundle(event: event, url: url)
                return
            }
            
            if event.fileRemoved {
                guard let note = self.storage.getBy(url: url), let project = note.project, project.isTrash else { return }
                
                self.removeNote(note: note)
            }
            
            if event.fileRenamed {
                self.moveHandler(url: url, pathList: self.observedFolders)
                return
            }
            
            guard self.checkFile(url: url, pathList: self.observedFolders) else {
                return
            }
            
            if event.fileChange {
                let wrappedNote = self.storage.getBy(url: url)
                
                if let note = wrappedNote, note.reload() {
                    note.markdownCache()
                    self.delegate.refillEditArea()
                } else {
                    self.importNote(url)
                }
                return
            }
            
            if event.fileCreated {
                self.importNote(url)
            }
        }
        
        watcher?.start()
    }
    
    private func moveHandler(url: URL, pathList: [String]) {
        let fileExistInFS = self.checkFile(url: url, pathList: pathList)
        
        guard let note = self.storage.getBy(url: url) else {
            if fileExistInFS {
                self.importNote(url)
            }
            return
        }
        
        if fileExistInFS {
            renameNote(note: note)
            return
        }
        
        removeNote(note: note)
    }
    
    private func checkFile(url: URL, pathList: [String]) -> Bool {
        return (
            FileManager.default.fileExists(atPath: url.path)
            && self.storage.allowedExtensions.contains(url.pathExtension)
            && pathList.contains(url.deletingLastPathComponent().path)
        )
    }
    
    private func importNote(_ url: URL) {
        let n = storage.getBy(url: url)
        guard n == nil else {
            if let nUnwrapped = n, nUnwrapped.url == UserDataService.instance.lastRenamed {
                self.delegate.updateTable() {
                    self.delegate.notesTableView.setSelected(note: nUnwrapped)
                    UserDataService.instance.lastRenamed = nil
                }
            }
            return
        }
        
        guard storage.getProjectBy(url: url) != nil else {
            return
        }
        
        let note = Note(url: url)
        note.parseURL()
        note.load(url)
        note.loadModifiedLocalAt()
        note.markdownCache()
        self.delegate.refillEditArea()
        
        print("FSWatcher import note: \"\(note.name)\"")
        self.storage.add(note)
        
        DispatchQueue.main.async {
            if let url = UserDataService.instance.lastRenamed,
                let note = self.storage.getBy(url: url) {
                self.delegate.updateTable() {
                    self.delegate.notesTableView.setSelected(note: note)
                    UserDataService.instance.lastRenamed = nil
                }
            } else {
                self.delegate.reloadView(note: note)
            }
        }
        
        if note.name == "FSNotes - Readme.md" {
            self.delegate.updateTable() {
                self.delegate.notesTableView.selectRow(0)
                note.addPin()
            }
        }
        
        self.delegate.reloadSideBar()
    }
    
    private func renameNote(note: Note) {
        if note.url == UserDataService.instance.lastRenamed {
            self.delegate.updateTable() {
                self.delegate.notesTableView.setSelected(note: note)
                UserDataService.instance.lastRenamed = nil
            }
        }
    }
    
    private func removeNote(note: Note) {
        print("FSWatcher remove note: \"\(note.name)\"")
        
        self.storage.removeNotes(notes: [note], fsRemove: false) { _ in
            DispatchQueue.main.async {
                if self.delegate.notesTableView.numberOfRows > 0 {
                    self.delegate.notesTableView.removeByNotes(notes: [note])
                }
            }
        }
    }
    
    private func handleTextBundle(event: FileWatcherEvent, url: URL) {
        if event.fileCreated && url.lastPathComponent == "text.markdown" {
            let path = url.deletingLastPathComponent().path
            let url = URL(fileURLWithPath: path)
            importNote(url)
        }
    }
    
    public func restart() {
        watcher?.stop()
        self.observedFolders = self.storage.getProjectPaths()
        start()
    }
}
