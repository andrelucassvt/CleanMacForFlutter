//
//  HomeView.swift
//  CleanMacForFlutters
//
//  Created by André  Lucas on 09/12/25.
//

import SwiftUI
import AppKit

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingApoiar = false
    // Estado para Full Disk Access
    @State private var hasFullDiskAccess: Bool? = nil
    @State private var fdaCheckInProgress = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let hasFDA = hasFullDiskAccess {
                    if hasFDA {
                        // Fluxo normal
                        VStack{
                            Text(NSLocalizedString("home.title", comment: ""))
                                .font(.title)
                                .padding(.vertical)
                            List {
                                Section {
                                    Button {
                                        viewModel.requestFolderPermission()
                                    } label: {
                                        Label(NSLocalizedString("home.select_folders", comment: ""), systemImage: "folder.badge.plus")
                                    }
                                }
                                
                                if viewModel.selectedFolders.isEmpty {
                                    Text(NSLocalizedString("home.empty_folders_message", comment: ""))
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(viewModel.selectedFolders) { folder in
                                        HStack {
                                            Toggle(isOn: Binding(
                                                get: { folder.activated },
                                                set: { _ in viewModel.toggleFolderActivation(folder) }
                                            )) {
                                                Label(URL(fileURLWithPath: folder.path).lastPathComponent, systemImage: "folder.fill")
                                                    .help(folder.path)
                                                    .lineLimit(2)
                                            }
                                            .toggleStyle(.switch)
                                            Spacer()
                                            Button(role: .destructive) {
                                                viewModel.removeFolder(folder)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                    .onDelete(perform: viewModel.deleteFolders)
                                }
                            }
                            .padding(.horizontal, 120)
                            
                            HStack{
                                Button(NSLocalizedString("home.run_clean", comment: "")) {
                                   viewModel.cleanCommand()
                               }
                               .foregroundStyle(.blue)
                               .disabled(viewModel.isRunningCommands)
                                Button(NSLocalizedString("home.github", comment: "")) {
                                    if let url = URL(string: "https://github.com/andrelucassvt/CleanMacForFlutter") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                Button(NSLocalizedString("home.support", comment: "")) {
                                    if let url = URL(string: "https://link.mercadopago.com.br/cleanmacforflutter") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                            .padding(.bottom, 50)
                        }
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "lock.trianglebadge.exclamationmark")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(.yellow)
                            
                            Text(NSLocalizedString("fda.required_title", comment: ""))
                                .font(.title2)
                                .multilineTextAlignment(.center)
                            
                            Text(NSLocalizedString("fda.required_description", comment: ""))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 520)
                            
                            VStack(spacing: 12) {
                                Button {
                                    openFullDiskAccessPreferences()
                                } label: {
                                    Text(NSLocalizedString("fda.open_settings", comment: ""))
                                        .frame(maxWidth: 340)
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button {
                                    checkFullDiskAccess()
                                } label: {
                                    HStack(spacing: 8) {
                                        if fdaCheckInProgress {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        Text(NSLocalizedString("fda.try_again", comment: ""))
                                    }
                                    .frame(maxWidth: 340)
                                }
                                .disabled(fdaCheckInProgress)
                            }
                            .padding(.top, 8)
                            
                            Text(NSLocalizedString("fda.instructions", comment: ""))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("fda.checking_permissions", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.loadPersistedFoldersIfNeeded()
            checkFullDiskAccess()
        }
        .overlay {
            if viewModel.isRunningCommands {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(NSLocalizedString("commands.executing", comment: ""))
                            .font(.headline)
                        
                        if !viewModel.currentProcessingFolder.isEmpty {
                            Text(viewModel.currentProcessingFolder)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(32)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                }
            }
        }
        .alert(NSLocalizedString("alert.error", comment: ""), isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
            Button(NSLocalizedString("alert.ok", comment: "")) {
                viewModel.errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .alert(NSLocalizedString("alert.success", comment: ""), isPresented: .constant(viewModel.successMessage != nil), presenting: viewModel.successMessage) { _ in
            Button(NSLocalizedString("alert.ok", comment: "")) {
                viewModel.successMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }
    
    // MARK: - Full Disk Access helpers
    
    private func checkFullDiskAccess() {
        fdaCheckInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Tente acessar um alvo que geralmente requer FDA.
            // Opção 1: diretório TCC (geralmente protegido)
            let protectedURL = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC")
            let hasAccess: Bool
            do {
                let _ = try FileManager.default.contentsOfDirectory(at: protectedURL, includingPropertiesForKeys: nil)
                hasAccess = true
            } catch {
                // Como fallback, tente outro alvo protegido
                let tmPlist = URL(fileURLWithPath: "/Library/Preferences/com.apple.TimeMachine.plist")
                if let _ = try? Data(contentsOf: tmPlist) {
                    hasAccess = true
                } else {
                    hasAccess = false
                }
            }
            DispatchQueue.main.async {
                self.hasFullDiskAccess = hasAccess
                self.fdaCheckInProgress = false
            }
        }
    }
    
    private func openFullDiskAccessPreferences() {
        // Abre a tela de Acesso total ao disco nas Configurações
        // Em macOS modernos, este esquema direciona para Privacidade > Acesso total ao disco
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    HomeView()
}
