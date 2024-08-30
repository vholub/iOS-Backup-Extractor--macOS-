import Foundation
import FMDB

// MARK: - File Operations

func getFileIDToNameMapping(manifestDBPath: String) -> [String: String]? {
    var fileIDToName = [String: String]()
    
    let dbURL = URL(fileURLWithPath: manifestDBPath)
    let db = FMDatabase(path: dbURL.path)
    
    guard db.open() else {
        print("Failed to open database.")
        return nil
    }
    
    defer {
        db.close()
    }
    
    do {
        let resultSet = try db.executeQuery("SELECT fileID, relativePath FROM Files", values: nil)
        while resultSet.next() {
            if let fileID = resultSet.string(forColumn: "fileID"),
               let relativePath = resultSet.string(forColumn: "relativePath") {
                fileIDToName[fileID] = relativePath
            }
        }
    } catch {
        print("Failed to execute query: \(error.localizedDescription)")
    }
    
    return fileIDToName
}

func ensureDirectoryExists(at path: String) {
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: path)
    
    if !fileManager.fileExists(atPath: url.path) {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error.localizedDescription)")
        }
    }
}

func renameFiles(backupDir: String, fileIDToName: [String: String]) {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: backupDir)
    
    if let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            if fileURL.hasDirectoryPath { continue }
            let fileID = fileURL.lastPathComponent
            if let relativePath = fileIDToName[fileID] {
                let destURL = directoryURL.appendingPathComponent(relativePath)
                ensureDirectoryExists(at: destURL.deletingLastPathComponent().path)
                
                do {
                    print("Renaming \(fileURL.path) to \(destURL.path)")
                    try fileManager.moveItem(at: fileURL, to: destURL)
                } catch {
                    print("Error renaming file: \(error.localizedDescription)")
                }
            }
        }
    }
}

func getFileType(for fileExtension: String) -> String {
    let imageExts = [".jpg", ".jpeg", ".png", ".gif", ".tiff"]
    let videoExts = [".mp4", ".mov", ".avi", ".mkv"]
    let documentExts = [".pdf", ".docx", ".xlsx", ".pptx"]
    
    let normalizedExtension = "." + fileExtension.lowercased()  // Přidáme tečku a převod na malá písmena

    if imageExts.contains(normalizedExtension) {
        return "Photos"
    } else if videoExts.contains(normalizedExtension) {
        return "Videos"
    } else if documentExts.contains(normalizedExtension) {
        return "Documents"
    } else {
        return "Others"
    }
}


func organizeFiles(backupRootDir: String) {
    let categories = ["Photos", "Videos", "Documents", "Others"]
    let fileManager = FileManager.default
    let rootURL = URL(fileURLWithPath: backupRootDir)
    
    for category in categories {
        let categoryURL = rootURL.appendingPathComponent(category)
        ensureDirectoryExists(at: categoryURL.path)
    }
    
    if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            if fileURL.hasDirectoryPath { continue }
            let fileExtension = fileURL.pathExtension.lowercased()
            let fileType = getFileType(for: fileExtension)
            
            // Ladicí výpis pro kontrolu
            print("Processing file: \(fileURL.lastPathComponent) with extension: \(fileExtension), categorized as: \(fileType)")
            
            let categoryURL = rootURL.appendingPathComponent(fileType)
            let destURL = categoryURL.appendingPathComponent(fileURL.lastPathComponent)
            
            ensureDirectoryExists(at: categoryURL.path)
            
            do {
                print("Moving \(fileURL.path) to \(destURL.path)")
                try fileManager.moveItem(at: fileURL, to: destURL)
            } catch {
                print("Error moving file: \(error.localizedDescription)")
            }
        }
    }
}

