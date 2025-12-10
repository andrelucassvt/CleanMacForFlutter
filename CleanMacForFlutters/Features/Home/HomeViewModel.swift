//
//  HomeViewModel.swift
//  CleanMacForFlutters
//
//  Created by André  Lucas on 09/12/25.
//

import Foundation
import AppKit
import SwiftUI

enum PersistenceKey {
    static let bookmarks = "selectedFoldersBookmarks"
}


@Observable
class HomeViewModel {
    var selectedFolders: [DocModel] = []
    var isRunningCommands = false
    var currentProcessingFolder: String = ""
    var errorMessage: String?
    var successMessage: String?
    var hasLoadedPersistedFolders = false
    

    
    func requestFolderPermission() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Selecionar"
        panel.message = "Escolha as pastas que deseja exibir"
        
        if panel.runModal() == .OK {
            addFolders(panel.urls)
        }
    }
    
    func addFolders(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var merged = selectedFolders
        
        for url in urls {
            let pathString = url.path
            if !merged.contains(where: { $0.path == pathString }) {
                let docModel = DocModel(path: pathString, activated: true)
                merged.append(docModel)
            }
        }
        selectedFolders = merged.sorted { 
            URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() < 
            URL(fileURLWithPath: $1.path).lastPathComponent.lowercased() 
        }
        persistFolders()
    }
    
    func deleteFolders(at offsets: IndexSet) {
        selectedFolders.remove(atOffsets: offsets)
        persistFolders()
    }
    
    func removeFolder(_ folder: DocModel) {
        selectedFolders.removeAll { $0.id == folder.id }
        persistFolders()
    }
    
    func toggleFolderActivation(_ folder: DocModel) {
        if let index = selectedFolders.firstIndex(where: { $0.id == folder.id }) {
            selectedFolders[index].activated.toggle()
            persistFolders()
        }
    }
    
    func loadPersistedFoldersIfNeeded() {
        guard !hasLoadedPersistedFolders else { return }
        hasLoadedPersistedFolders = true
        guard let stored = UserDefaults.standard.array(forKey: PersistenceKey.bookmarks) as? [Data] else { return }
        
        var resolved: [DocModel] = []
        for data in stored {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                let docModel = DocModel(path: url.path, activated: true)
                resolved.append(docModel)
            }
        }
        
        selectedFolders = resolved.sorted { 
            URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() < 
            URL(fileURLWithPath: $1.path).lastPathComponent.lowercased() 
        }
    }
    
    private func persistFolders() {
        let bookmarks: [Data] = selectedFolders.compactMap { docModel in
            let url = URL(fileURLWithPath: docModel.path)
            return try? url.bookmarkData(options: [.withSecurityScope],
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: PersistenceKey.bookmarks)
    }
    
    
    func cleanCommand() {
        let activatedFolders = selectedFolders.filter { $0.activated }
        
        guard !activatedFolders.isEmpty else {
            errorMessage = "Nenhuma pasta ativada para executar a limpeza."
            return
        }
        
        Task {
            await MainActor.run {
                self.isRunningCommands = true
                self.errorMessage = nil
                self.successMessage = nil
            }
            
            var deletedCount = 0
            var failedCount = 0
            var totalSize: Int64 = 0
            
            // Pastas a remover em cada projeto
            let targets = ["build", ".dart_tool", "pubspec.lock", "ios/Pods", "ios/Podfile.lock", "ios/Gemfile.lock"]
            
            for folder in activatedFolders {
                let folderURL = URL(fileURLWithPath: folder.path)
                
                await MainActor.run {
                    self.currentProcessingFolder = folderURL.lastPathComponent
                }
                
                print("\n🔄 Verificando: \(folderURL.lastPathComponent)")
                
                for target in targets {
                    let targetPath = folderURL.appendingPathComponent(target)
                    
                    if FileManager.default.fileExists(atPath: targetPath.path) {
                        do {
                            if let size = try? FileManager.default.allocatedSizeOfDirectory(at: targetPath) {
                                totalSize += size
                                print("📦 Tamanho da pasta \(target): \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                            }
                            
                            try FileManager.default.removeItem(at: targetPath)
                            deletedCount += 1
                            print("✅ Pasta \(target) deletada em: \(folderURL.lastPathComponent)")
                        } catch {
                            failedCount += 1
                            print("❌ Erro ao deletar \(target) em \(folderURL.lastPathComponent): \(error.localizedDescription)")
                        }
                    } else {
                        print("ℹ️ Pasta \(target) não encontrada em: \(folderURL.lastPathComponent)")
                    }
                }
            }
            
            await MainActor.run {
                self.isRunningCommands = false
                self.currentProcessingFolder = ""
                
                if deletedCount > 0 {
                    let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                    self.successMessage = "Limpeza concluída!\n\n✅ \(deletedCount) pasta(s) deletada(s)\n\n💾 \(sizeString) liberados"
                    if failedCount > 0 {
                        self.successMessage! += "\n⚠️ \(failedCount) falha(s)"
                    }
                } else if failedCount > 0 {
                    self.errorMessage = "Nenhuma pasta foi deletada. \(failedCount) erro(s) encontrado(s)."
                } else {
                    self.successMessage = "Nenhuma pasta 'build' ou '.dart_tool' foi encontrada nos projetos selecionados."
                }
            }
            
            print("\n✅ Limpeza finalizada! Deletadas: \(deletedCount) | Falhas: \(failedCount)")
        }
    }
        
}

// Extensão para calcular tamanho de diretório
extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = self.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        while let item = enumerator.nextObject() as? URL {
            let resourceValues = try item.resourceValues(forKeys: keys)
            
            // Consider only regular files
            if let isRegular = resourceValues.isRegularFile, isRegular {
                if let total = resourceValues.totalFileAllocatedSize {
                    totalSize += Int64(total)
                } else if let file = resourceValues.fileAllocatedSize {
                    totalSize += Int64(file)
                }
            }
        }
        
        return totalSize
    }
}
