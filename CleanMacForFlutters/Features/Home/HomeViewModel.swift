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
    
    // MARK: - Build & Index Clean

    /// URL salva do diretório Xcode selecionado pelo usuário
    var xcodeDirectoryBookmark: Data? {
        get { UserDefaults.standard.data(forKey: "xcodeDirectoryBookmark") }
        set { UserDefaults.standard.set(newValue, forKey: "xcodeDirectoryBookmark") }
    }

    /// Estado para o popup de confirmação
    var showBuildIndexConfirmation = false
    var buildIndexSizeDescription: String = ""
    private var resolvedXcodeURL: URL?

    /// Resolve o bookmark salvo para uma URL com acesso security-scoped
    private func resolveXcodeBookmark() -> URL? {
        guard let data = xcodeDirectoryBookmark else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else { return nil }
        if isStale {
            // Regrava o bookmark atualizado
            if let newData = try? url.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) {
                xcodeDirectoryBookmark = newData
            }
        }
        return url
    }

    /// Seleciona a pasta Xcode via NSOpenPanel e salva o bookmark
    func selectXcodeDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let xcodeDevDir = home.appendingPathComponent("Library/Developer/Xcode")

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = xcodeDevDir
        panel.prompt = NSLocalizedString("build.index.select.confirm", comment: "")
        panel.message = NSLocalizedString("build.index.select.message", comment: "")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        // Salva bookmark para reusar sem pedir de novo
        if let data = try? selectedURL.bookmarkData(options: [.withSecurityScope],
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil) {
            xcodeDirectoryBookmark = data
        }
    }

    /// Chamado pelo botão: se já tem pasta salva, calcula tamanho e mostra confirmação; senão, pede para selecionar
    func cleanBuildAndIndexCommand() {
        guard let url = resolveXcodeBookmark() else {
            // Primeira vez: pede para selecionar
            selectXcodeDirectory()
            return
        }

        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        // Calcula tamanho total
        var totalSize: Int64 = 0
        let targets = ["DerivedData", "Index"]

        for targetName in targets {
            let target = url.appendingPathComponent(targetName)
            if FileManager.default.fileExists(atPath: target.path),
               let size = try? FileManager.default.allocatedSizeOfDirectory(at: target) {
                totalSize += size
            }
        }

        let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        buildIndexSizeDescription = sizeString
        resolvedXcodeURL = url

        // Mostra popup de confirmação
        showBuildIndexConfirmation = true
    }

    /// Executa a limpeza de fato (chamado após confirmação do usuário)
    func confirmCleanBuildAndIndex() {
        guard let selectedURL = resolvedXcodeURL else { return }

        let hasAccess = selectedURL.startAccessingSecurityScopedResource()

        Task {
            await MainActor.run {
                self.isRunningCommands = true
                self.errorMessage = nil
                self.successMessage = nil
                self.currentProcessingFolder = NSLocalizedString("build.index.processing", comment: "")
            }

            var deletedCount = 0
            var failedCount = 0
            var totalSize: Int64 = 0

            let targets = ["DerivedData", "Index"]

            for targetName in targets {
                let target = selectedURL.appendingPathComponent(targetName)

                guard FileManager.default.fileExists(atPath: target.path) else {
                    print("ℹ️ Não encontrado: \(target.path)")
                    continue
                }

                if let size = try? FileManager.default.allocatedSizeOfDirectory(at: target) {
                    totalSize += size
                }

                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
                    for item in contents {
                        try FileManager.default.removeItem(at: item)
                        deletedCount += 1
                        print("✅ Deletado: \(item.lastPathComponent)")
                    }
                } catch {
                    failedCount += 1
                    print("❌ Erro em \(targetName): \(error.localizedDescription)")
                }
            }

            if hasAccess {
                selectedURL.stopAccessingSecurityScopedResource()
            }

            await MainActor.run {
                self.isRunningCommands = false
                self.currentProcessingFolder = ""

                if deletedCount > 0 {
                    let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                    let title = NSLocalizedString("build.index.completed.title", comment: "")
                    let space = String(format: NSLocalizedString("clean.completed.space", comment: ""), sizeString)
                    var message = "\(title)\n\n\(space)"
                    if failedCount > 0 {
                        let warnings = String(format: NSLocalizedString("clean.completed.warnings", comment: ""), failedCount)
                        message += "\n\(warnings)"
                    }
                    self.successMessage = message
                } else if failedCount > 0 {
                    self.errorMessage = String(format: NSLocalizedString("clean.none.deleted.errors", comment: ""), failedCount)
                } else {
                    self.successMessage = NSLocalizedString("build.index.nothing.found", comment: "")
                }
            }
        }
    }

    func cleanCommand() {
        let activatedFolders = selectedFolders.filter { $0.activated }
        
        guard !activatedFolders.isEmpty else {
            errorMessage = NSLocalizedString("clean.no.activated", comment: "No activated folders to clean")
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
                    let title = NSLocalizedString("clean.completed.title", comment: "Cleaning completed title")
                    let summary = String(format: NSLocalizedString("clean.completed.summary", comment: "Deleted count summary"), deletedCount)
                    let space = String(format: NSLocalizedString("clean.completed.space", comment: "Freed space summary"), sizeString)
                    var message = "\(title)\n\n\(summary)\n\n\(space)"
                    if failedCount > 0 {
                        let warnings = String(format: NSLocalizedString("clean.completed.warnings", comment: "Warnings count"), failedCount)
                        message += "\n\(warnings)"
                    }
                    self.successMessage = message
                } else if failedCount > 0 {
                    self.errorMessage = String(format: NSLocalizedString("clean.none.deleted.errors", comment: "None deleted but errors occurred"), failedCount)
                } else {
                    self.successMessage = NSLocalizedString("clean.nothing.found", comment: "Nothing to clean found")
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
