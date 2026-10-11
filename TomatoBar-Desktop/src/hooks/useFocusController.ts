import { useEffect, useSyncExternalStore } from "react";
import { desktop } from "../platform/desktop";
import { FocusController } from "../application/focusController";

export function useFocusController(controller: FocusController) {
  const snapshot = useSyncExternalStore(
    controller.subscribe,
    controller.getSnapshot,
  );
  useEffect(() => {
    void controller.initialize();
    if (!desktop.isNative()) {
      const timer = window.setInterval(() => {
        void controller.tick();
      }, 1000);
      return () => window.clearInterval(timer);
    }
    let disposed = false;
    let cleanup: (() => void) | undefined;
    void desktop
      .onTick(() => {
        void controller.tick();
      })
      .then((unsubscribe) => {
        if (disposed) unsubscribe();
        else cleanup = unsubscribe;
      });
    return () => {
      disposed = true;
      cleanup?.();
    };
  }, [controller]);
  return snapshot;
}
