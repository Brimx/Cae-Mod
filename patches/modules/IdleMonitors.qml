pragma ComponentBehavior: Bound

import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services
import qs.services

Scope {
    id: root

    required property Lock lock

    readonly property bool audioPlaying: Players.list.some(p => p.isPlaying)
    property bool debouncedPlaying: false

    Timer {
        id: debounce
        interval: 5000
        onTriggered: debouncedPlaying = false
    }

    onAudioPlayingChanged: {
        if (audioPlaying) {
            debounce.stop()
            debouncedPlaying = true
        } else {
            debounce.restart()
        }
    }

    readonly property bool inhibit: GlobalConfig.general.idle.inhibitWhenAudio && debouncedPlaying
    readonly property var effectiveTimeouts: inhibit ? [] : GlobalConfig.general.idle.timeouts

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        else if (!SessionManager.exec(action))
            Quickshell.execDetached(action);
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        model: root.effectiveTimeouts

        IdleMonitor {
            required property var modelData

            enabled: modelData.enabled ?? true
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
