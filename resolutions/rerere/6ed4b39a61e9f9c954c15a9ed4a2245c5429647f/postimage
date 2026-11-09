import type { KeyboardInputEvent } from "@/keyboard";
import { resolveListSearchKeyAction } from "@/keyboard/list-search-keys";
export function navigateMenuKeyboard(event: KeyboardInputEvent): boolean {
  const action = resolveListSearchKeyAction(event);
  const target = document.activeElement;
  const surface = target?.closest<HTMLElement>('[data-menu-surface="true"]');
  if (!surface) return false;
  const items = Array.from(
    surface.querySelectorAll<HTMLElement>(
      '[data-menu-item="true"]:not([data-menu-disabled="true"])',
    ),
  );
  if (items.length === 0) return false;
  const currentIndex = items.findIndex((item) => item === document.activeElement);

  if (action === "submit" || event.key === " ") {
    if (currentIndex < 0) return false;
    event.preventDefault();
    event.stopPropagation();
    items[currentIndex]?.click();
    return true;
  }

  let nextIndex: number | null = null;
  if (action === "next") nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % items.length;
  if (action === "previous")
    nextIndex =
      currentIndex < 0 ? items.length - 1 : (currentIndex - 1 + items.length) % items.length;
  if (event.key === "Home") nextIndex = 0;
  if (event.key === "End") nextIndex = items.length - 1;
  if (nextIndex !== null) {
    event.preventDefault();
    event.stopPropagation();
    items[nextIndex]?.focus();
    return true;
  }
  return false;
}
