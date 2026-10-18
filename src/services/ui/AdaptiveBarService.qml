pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../theme"
import "../"

Singleton {
    id: root
    property var providers: []
    property var overlays: []
    function register(provider) { providers = providers.concat([provider]) }
    function unregister(provider) { providers = providers.filter(item => item !== provider) }
    function registerOverlay(overlay) { overlays = overlays.concat([overlay]) }
    function unregisterOverlay(overlay) { overlays = overlays.filter(item => item !== overlay) }
    function providerFor(screen) { return Config.adaptiveBarEnabled ? providers.find(item => item.screen === screen) : null }
    function backgroundFor(screen) { return providerFor(screen)?.background ?? Theme.background }
    function islandsFor(screen) { return providerFor(screen)?.islands ?? false }
    function foregrounds(screen) {
        const colors = [];
        function visit(item, opacity) {
            if (!item || !item.visible) return;
            const effectiveOpacity = opacity * item.opacity;
            // Read color only: editable/secret field contents are never inspected.
            // Deliberately dim workspace markers retain their decorative role.
            if (item instanceof Text && effectiveOpacity >= 0.85 && item.color.a >= 0.85) colors.push(item.color);
            for (const child of item.children) visit(child, effectiveOpacity);
        }
        visit(providerFor(screen)?.foregroundRoot, 1);
        for (const overlay of overlays)
            if (overlay.host.screen === screen && overlay.presentationPending) visit(overlay.host.contentItem, 1);
        return colors;
    }
    function blocked(screen) {
        return CaptureHandoffService.active || MediaFullscreenService.visible
            || (PickerService.visible && PickerService.layout === "expose") || NotificationService.popups.length > 0
            || overlays.some(item => item.host.screen === screen && (item.requested || item.presentationPending));
    }
    function bridges(screen) {
        if (!islandsFor(screen)) return [];
        return overlays.filter(item => item.host.screen === screen && item.presentationPending
            && item.host.surfaceComponent?.motion?.fraction > 0).map(item => {
            const motion = item.host.surfaceComponent.motion;
            return {x:motion.displayedX, width:motion.displayedWidth,
                opacity:motion.fraction};
        });
    }
    IpcHandler {
        target: "adaptivebar"
        function status(): string {
            return JSON.stringify(root.providers.map(provider => ({screen:provider.screen.name,
                workspace:provider.workspaceKey,status:provider.status,sampled:provider.capturedColor,
                background:String(provider.background),foregrounds:provider.indicators.length})));
        }
    }
}
