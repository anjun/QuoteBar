import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @MainActor
    static func toggle() {
        do {
            try setEnabled(!isEnabled)
        } catch {
            AppUpdater.alert(
                "无法设置登录时打开",
                "请把 QuoteBar 放到「应用程序」后再试，或在系统设置 ▸ 通用 ▸ 登录项与扩展 中允许。"
            )
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
                return
            default:
                break
            }
            do {
                try service.register()
            } catch {
                if isAlreadyRegistered(error) {
                    return
                }
                if isDeniedByUser(error) {
                    SMAppService.openSystemSettingsLoginItems()
                    return
                }
                throw error
            }
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else if service.status != .notRegistered {
            do {
                try service.unregister()
            } catch {
                if isJobNotFound(error) { return }
                throw error
            }
        }
    }

    private static func isAlreadyRegistered(_ error: Error) -> Bool {
        (error as NSError).code == kSMErrorAlreadyRegistered
    }

    private static func isJobNotFound(_ error: Error) -> Bool {
        (error as NSError).code == kSMErrorJobNotFound
    }

    private static func isDeniedByUser(_ error: Error) -> Bool {
        (error as NSError).code == kSMErrorLaunchDeniedByUser
    }
}
