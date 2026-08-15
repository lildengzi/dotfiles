import Quickshell
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "liveLyrics"

    StyledText {
        width: parent.width
        text: "Live Lyrics Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure lyrics sources and behavior"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: durationsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: durationsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Cache"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "cachingEnabled"
                label: "Local Cache"
                description: "Save downloaded lyrics locally to speed up loading times and reduce network requests. (Recommended)"
                defaultValue: true
            }
        }
    }

    StyledRect {
        width: parent.width
        height: sourcesColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: sourcesColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            readonly property var opts: [
                {
                    label: "none",
                    value: "none"
                },
                {
                    label: "navidrome",
                    value: "navidrome"
                },
                {
                    label: "lrclib",
                    value: "lrclib"
                },
                {
                    label: "musixmatch",
                    value: "musixmatch"
                },
                {
                    label: "lrcapi",
                    value: "lrcapi"
                }
            ]

            StyledText {
                text: "Source Priority"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: "Pick sources in order (top = first)"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "source1"
                label: "Source 1"
                options: sourcesColumn.opts
                defaultValue: "navidrome"
            }

            SelectionSetting {
                settingKey: "source2"
                label: "Source 2"
                options: sourcesColumn.opts
                defaultValue: "lrclib"
            }

            SelectionSetting {
                settingKey: "source3"
                label: "Source 3"
                options: sourcesColumn.opts
                defaultValue: "musixmatch"
            }

            SelectionSetting {
                settingKey: "source4"
                label: "Source 4"
                options: sourcesColumn.opts
                defaultValue: "lrcapi"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: behaviorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: behaviorColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Navidrome"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "navidromeUrl"
                label: "Server URL"
                description: "The full address of your instance."
                placeholder: "https://music.example.com:4533"
                defaultValue: ""
            }

            StringSetting {
                settingKey: "navidromeUser"
                label: "Username"
                placeholder: "username"
                defaultValue: ""
            }

            StringSetting {
                settingKey: "navidromePassword"
                label: "Password"
                placeholder: "password"
                defaultValue: ""
            }
        }
    }

    StyledRect {
        width: parent.width
        height: whitelistColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        Column {
            id: whitelistColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Player Whitelist"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "playerWhitelist"
                label: "Allowed Players"
                description: "Only players in this list will be allowed to control the music player."
                placeholder: "lx-music-desktop, spotify"
                defaultValue: ""
            }
        }
    }
}
