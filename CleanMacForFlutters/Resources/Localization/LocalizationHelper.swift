//
//  LocalizationHelper.swift
//  CleanMacForFlutters
//
//  Created by André Lucas on 10/12/25.
//

import Foundation

/// Helper para facilitar o acesso a strings localizadas
enum LocalizedString {
    // MARK: - Home View
    case homeTitle
    case homeSelectFolders
    case homeEmptyFoldersMessage
    case homeRunClean
    case homeGithub
    case homeSupport
    
    // MARK: - Full Disk Access
    case fdaRequiredTitle
    case fdaRequiredDescription
    case fdaOpenSettings
    case fdaTryAgain
    case fdaCheckingPermissions
    case fdaInstructions
    
    // MARK: - Commands
    case commandsExecuting
    case commandsProcessingFolder(String)
    
    // MARK: - Alerts
    case alertError
    case alertSuccess
    case alertOk
    
    var key: String {
        switch self {
        // Home View
        case .homeTitle: return "home.title"
        case .homeSelectFolders: return "home.select_folders"
        case .homeEmptyFoldersMessage: return "home.empty_folders_message"
        case .homeRunClean: return "home.run_clean"
        case .homeGithub: return "home.github"
        case .homeSupport: return "home.support"
            
        // Full Disk Access
        case .fdaRequiredTitle: return "fda.required_title"
        case .fdaRequiredDescription: return "fda.required_description"
        case .fdaOpenSettings: return "fda.open_settings"
        case .fdaTryAgain: return "fda.try_again"
        case .fdaCheckingPermissions: return "fda.checking_permissions"
        case .fdaInstructions: return "fda.instructions"
            
        // Commands
        case .commandsExecuting: return "commands.executing"
        case .commandsProcessingFolder: return "commands.processing_folder"
            
        // Alerts
        case .alertError: return "alert.error"
        case .alertSuccess: return "alert.success"
        case .alertOk: return "alert.ok"
        }
    }
    
    var localized: String {
        switch self {
        case .commandsProcessingFolder(let folderName):
            return String(format: NSLocalizedString(key, comment: ""), folderName)
        default:
            return NSLocalizedString(key, comment: "")
        }
    }
}

// Extension para facilitar o uso
extension String {
    /// Retorna a string localizada usando a chave fornecida
    static func localized(_ key: LocalizedString) -> String {
        return key.localized
    }
}
