import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Global shortcut: Option-Space")
            Text("For editable shortcuts, add KeyboardShortcuts from https://github.com/sindresorhus/KeyboardShortcuts and replace the native prototype hotkey.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 440)
    }
}

