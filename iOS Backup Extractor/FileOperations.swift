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

func renameFiles(backupDir: String, fileIDToName: [String: String], updateProgress: @escaping (Int) -> Void) {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: backupDir)
    var processedFiles = 0  // Zde sledujeme počet zpracovaných souborů
    
    if let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            if fileURL.hasDirectoryPath { continue }
            let fileID = fileURL.lastPathComponent
            if let relativePath = fileIDToName[fileID] {
                var destURL = directoryURL.appendingPathComponent(relativePath)
                ensureDirectoryExists(at: destURL.deletingLastPathComponent().path)
                
                // Kontrola, zda soubor již existuje, a vytvoření jedinečného názvu souboru
                destURL = makeUnique(destURL: destURL)
                
                do {
                    print("Renaming \(fileURL.path) to \(destURL.path)")
                    try fileManager.moveItem(at: fileURL, to: destURL)
                } catch {
                    print("Error renaming file: \(error.localizedDescription)")
                }
            }
            
            // Zvyšte počet zpracovaných souborů a aktualizujte průběh
            processedFiles += 1
            updateProgress(processedFiles)  // Voláme uzávěr pro aktualizaci progressu
        }
    }
}


func organizeFiles(backupRootDir: String, updateProgress: @escaping (Int) -> Void) {
    let categories = ["Photos", "Videos", "Documents", "Others", "EmptyFiles"]
    let fileManager = FileManager.default
    let rootURL = URL(fileURLWithPath: backupRootDir)
    var processedFiles = 0  // Zde sledujeme počet zpracovaných souborů

    // Vytvoříme složky pro základní kategorie a iPhone podsložky
    for category in categories {
        let categoryURL = rootURL.appendingPathComponent(category)
        ensureDirectoryExists(at: categoryURL.path)

        // Přidáme i podsložky pro iPhone fotky a videa
        if category == "Photos" || category == "Videos" {
            let iphoneSubfolder = category == "Photos" ? "Photos-iPhone" : "Videos-iPhone"
            let iphoneSubfolderURL = categoryURL.appendingPathComponent(iphoneSubfolder)
            ensureDirectoryExists(at: iphoneSubfolderURL.path)
        }
    }

    // Enumerace souborů v root složce zálohy
    if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.fileSizeKey]) {
        for case let fileURL as URL in enumerator {
            if fileURL.hasDirectoryPath { continue }

            // Kontrola velikosti souboru
            let fileAttributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = fileAttributes?.fileSize, fileSize == 0 {
                // Pokud má soubor velikost 0, přesuneme ho do složky EmptyFiles
                let emptyFilesURL = rootURL.appendingPathComponent("EmptyFiles").appendingPathComponent(fileURL.lastPathComponent)
                
                do {
                    print("Moving empty file \(fileURL.path) to \(emptyFilesURL.path)")
                    try fileManager.moveItem(at: fileURL, to: emptyFilesURL)
                } catch {
                    print("Error moving empty file: \(error.localizedDescription)")
                }
            } else {
                // Zpracování neprázdných souborů
                let fileExtension = fileURL.pathExtension.lowercased()
                let fileName = fileURL.lastPathComponent
                
                // Použijeme název souboru i příponu k určení cílové složky
                let fileType = getFileType(for: fileName, fileExtension: fileExtension)
                
                print("Processing file: \(fileName) with extension: \(fileExtension), categorized as: \(fileType)")
                
                let categoryURL = rootURL.appendingPathComponent(fileType)
                let destURL = categoryURL.appendingPathComponent(fileName)
                
                ensureDirectoryExists(at: categoryURL.path)
                
                do {
                    print("Moving \(fileURL.path) to \(destURL.path)")
                    try fileManager.moveItem(at: fileURL, to: destURL)
                } catch {
                    print("Error moving file: \(error.localizedDescription)")
                }
            }

            // Zvyšte počet zpracovaných souborů a aktualizujte průběh
            processedFiles += 1
            updateProgress(processedFiles)  // Voláme uzávěr pro aktualizaci progressu
        }
    }
}





// Funkce pro vytvoření jedinečného názvu souboru
func makeUnique(destURL: URL) -> URL {
    var uniqueURL = destURL
    let fileManager = FileManager.default
    var counter = 1
    
    while fileManager.fileExists(atPath: uniqueURL.path) {
        // Přidáme číslo ke jménu souboru před příponu, například "Cookies (1).binarycookies"
        let fileName = uniqueURL.deletingPathExtension().lastPathComponent
        let fileExtension = uniqueURL.pathExtension
        let newFileName = "\(fileName) (\(counter)).\(fileExtension)"
        uniqueURL = uniqueURL.deletingLastPathComponent().appendingPathComponent(newFileName)
        counter += 1
    }
    
    return uniqueURL
}


func getFileType(for fileName: String, fileExtension: String) -> String {
    let imageExts = [".jpg", ".jpeg", ".png", ".gif", ".tiff", ".heic"]
    let videoExts = [".mp4", ".mov", ".avi", ".mkv"]
    let documentExts = [".pdf", ".docx", ".xlsx", ".pptx"]
    
    let normalizedExtension = "." + fileExtension.lowercased()  // Přidáme tečku a převod na malá písmena

    if fileName.hasPrefix("IMG_") {
        if imageExts.contains(normalizedExtension) {
            return "Photos/Photos-iPhone"
        } else if videoExts.contains(normalizedExtension) {
            return "Videos/Videos-iPhone"
        }
    }
    
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


