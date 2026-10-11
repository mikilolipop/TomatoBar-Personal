import { useEffect, useRef } from "react";
import type { ReactNode } from "react";

/** Native dialog supplies focus containment, Escape and restoration for every modal. */
export function Modal({
  title,
  className = "garden-modal-overlay",
  onClose,
  children,
}: {
  title: string;
  className?: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const close = useRef(onClose);
  useEffect(() => {
    close.current = onClose;
  }, [onClose]);
  useEffect(() => {
    const element = dialog.current!;
    element.showModal();
    return () => element.close();
  }, []);
  return (
    <dialog
      ref={dialog}
      className={className}
      aria-label={title}
      onCancel={(e) => {
        e.preventDefault();
        close.current();
      }}
    >
      {children}
    </dialog>
  );
}
