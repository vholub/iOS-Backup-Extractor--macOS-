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

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .padding()
            }
        }
        .frame(width: 500, height: 200)
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
        
        isProcessing = true
        resultMessage = "Processing..."

        DispatchQueue.global(qos: .background).async {
            let manifestDBPath = (backupRootDir as NSString).appendingPathComponent("Manifest.db")

            if FileManager.default.fileExists(atPath: manifestDBPath) {
                if let fileIDToName = getFileIDToNameMapping(manifestDBPath: manifestDBPath) {
                    renameFiles(backupDir: backupRootDir, fileIDToName: fileIDToName)
                    organizeFiles(backupRootDir: backupRootDir)
                    
                    DispatchQueue.main.async {
                        resultMessage = "Processing completed successfully."
                    }
                } else {
                    DispatchQueue.main.async {
                        resultMessage = "Failed to load Manifest.db."
                    }
                }
            } else {
                DispatchQueue.main.async {
                    resultMessage = "Manifest.db not found."
                }
            }

            isProcessing = false
        }
    }
}

#Preview {
    ContentView()
}
