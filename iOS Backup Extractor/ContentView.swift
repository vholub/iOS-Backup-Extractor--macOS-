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
    @State private var progress: Double = 0.0  // Stav pro sledování průběhu
    @State private var remainingTime: String = ""  // Nový stav pro zbývající čas
    @State private var startTime: Date? = nil  // Uchová startovní čas
    @State private var timer: Timer? = nil  // Časovač pro aktualizaci zbývajícího času

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
                
                Text(String(format:"%.0f %%", progress * 100))  // Zobrazení procent
                    .padding()
                
                if !remainingTime.isEmpty {
                    Text("Estimated time remaining: \(remainingTime)")  // Zobrazení zbývajícího času
                        .padding()
                }
            }

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .padding()
            }
        }
        .frame(width: 500, height: 300)  // Upravená výška pro zahrnutí zbývajícího času
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
        
        if !FileManager.default.fileExists(atPath: manifestDBPath) {
            showAlert()
            return
        }

        isProcessing = true
        resultMessage = ""
        progress = 0.0
        startTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if let startTime = startTime {
                let elapsedTime = Date().timeIntervalSince(startTime)
                
                // Zkontrolujeme, jestli je progress větší než 0
                if progress > 0 {
                    let estimatedTotalTime = elapsedTime / progress * 1.0
                    let remainingTimeInterval = estimatedTotalTime - elapsedTime
                    
                    if remainingTimeInterval > 0 {
                        remainingTime = formatTime(seconds: Int(remainingTimeInterval))
                    } else {
                        remainingTime = "Less than a minute"
                    }
                } else {
                    remainingTime = "Calculating..."  // Pokud progress je 0, zobrazí se toto
                }
            }
        }


        DispatchQueue.global(qos: .background).async {
            if let fileIDToName = getFileIDToNameMapping(manifestDBPath: manifestDBPath) {
                let totalFiles = fileIDToName.count
                let totalSteps = totalFiles * 2  // Přejmenování + organizace

                renameFiles(backupDir: backupRootDir, fileIDToName: fileIDToName, updateProgress: { progressValue in
                    DispatchQueue.main.async {
                        let renameProgress = Double(progressValue) / Double(totalFiles)
                        progress = renameProgress / 2  // První polovina pro přejmenování
                    }
                })

                organizeFiles(backupRootDir: backupRootDir, updateProgress: { progressValue in
                    DispatchQueue.main.async {
                        let organizeProgress = Double(progressValue) / Double(totalFiles)
                        progress = 0.5 + organizeProgress / 2  // Druhá polovina pro organizaci
                    }
                })

                DispatchQueue.main.async {
                    resultMessage = "Processing completed successfully."
                    isProcessing = false
                    timer?.invalidate()
                }
            } else {
                DispatchQueue.main.async {
                    resultMessage = "Failed to load Manifest.db."
                    isProcessing = false
                    timer?.invalidate()
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

    // Funkce pro formátování času
    private func formatTime(seconds: Int) -> String {
        let minutes = (seconds % 3600) / 60
        if minutes > 0 {
            return String(format: "%d minutes", minutes)
        } else {
            return "Less than a minute"
        }
    }
}

#Preview {
    ContentView()
}
