//
//  ContentView.swift
//  iOS Backup Extractor
//
//  Created by Vratislav Holub on 29.08.2024.
//

import SwiftUI
import AppKit // Import AppKit pro použití NSOpenPanel

struct ContentView: View {
    @State private var backupRootDir: String = ""
    @State private var isProcessing = false
    @State private var resultMessage: String = ""
    @State private var progress: Double = 0.0  // Nový stav pro sledování průběhu

    var body: some View {
        VStack {
            Text("iOS Backup Extractor (od Vratika)")
                .font(.largeTitle)
                .padding()

            HStack {
                TextField("Path to backup directory", text: $backupRootDir)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: selectFolder) {
                    Text("Select Folder")
                }
                .padding()
            }

            Button(action: startProcessing) {
                Text("Start Processing")
            }
            .disabled(isProcessing || backupRootDir.isEmpty)
            .padding()

            if isProcessing {
                ProgressView(value: progress, total: 1.0)  // Progress bar
                    .padding()
                
                //zobrazení procent ještě
                Text(String(format:"%.0f %%", progress*100))
                    .padding()
            }

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .padding()
            }
        }
        .frame(width: 500, height: 250)  // Upravená výška pro zahrnutí ProgressView
        .padding()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            backupRootDir = url.path
        }
    }

    private func startProcessing() {
        guard !backupRootDir.isEmpty else { return }
        
        let manifestDBPath = (backupRootDir as NSString).appendingPathComponent("Manifest.db")
        
        // Kontrola přítomnosti Manifest.db
        if !FileManager.default.fileExists(atPath: manifestDBPath) {
            showAlert()
            return
        }

        isProcessing = true
        resultMessage = "Processing..."
        progress = 0.0  // Resetuje progress

        DispatchQueue.global(qos: .background).async {
            if let fileIDToName = getFileIDToNameMapping(manifestDBPath: manifestDBPath) {
                let totalFiles = fileIDToName.count  // Počet souborů pro progress

                renameFiles(backupDir: backupRootDir, fileIDToName: fileIDToName, updateProgress: { progressValue in
                    DispatchQueue.main.async {
                        progress = Double(progressValue) / Double(totalFiles)  // Aktualizace progressu
                    }
                })

                organizeFiles(backupRootDir: backupRootDir, updateProgress: { progressValue in
                    DispatchQueue.main.async {
                        progress = Double(progressValue) / Double(totalFiles)
                    }
                })
                
                DispatchQueue.main.async {
                    resultMessage = "Processing completed successfully."
                    isProcessing = false
                }
            } else {
                DispatchQueue.main.async {
                    resultMessage = "Failed to load Manifest.db."
                    isProcessing = false
                }
            }
        }
    }

    // Funkce pro zobrazení alertu
    private func showAlert() {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = "Probably the wrong folder. The file Manifest.db was not found in the selected folder."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}


#Preview {
    ContentView()
}
