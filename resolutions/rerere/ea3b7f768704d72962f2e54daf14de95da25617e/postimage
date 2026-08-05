import type { Page } from "@playwright/test";
import { expect, test } from "../support/fixtures";
import { gotoAppShell } from "../support/helpers/app";
import { seedWorkspace } from "../support/helpers/seed-client";
import { getServerId } from "../support/helpers/server-id";
import { archiveWorkspaceFromSidebar } from "../support/helpers/sidebar";
import { waitForSidebarHydration } from "../support/helpers/workspace-ui";

async function wasRecentlyArchivedPendingSeen(page: Page): Promise<boolean> {
  return page.evaluate(
    () =>
      (window as typeof window & { __recentlyArchivedPendingSeen?: boolean })
        .__recentlyArchivedPendingSeen ?? false,
  );
}

test.describe("Recently archived sidebar transition", () => {
  test("moves a status row through the pending indicator and restores it", async ({ page }) => {
    const workspace = await seedWorkspace({
      repoPrefix: "sidebar-recently-archived-",
      title: "Archive transition workspace",
    });
    const serverId = getServerId();
    const workspaceKey = `${serverId}:${workspace.workspaceId}`;
    const liveRow = page.getByTestId(`sidebar-workspace-row-${workspaceKey}`);
    const pendingRow = page.getByTestId(`sidebar-archived-pending-${workspaceKey}`);
    const restoreButton = page.getByTestId(`sidebar-archived-unarchive-${workspaceKey}`);

    try {
      await gotoAppShell(page);
      await waitForSidebarHydration(page);
      await page.getByTestId("sidebar-display-preferences-menu").click();
      await page.getByTestId("sidebar-grouping-status").click();
      await expect(liveRow).toBeVisible({ timeout: 30_000 });

      await page.evaluate(() => {
        const trackedWindow = window as typeof window & {
          __recentlyArchivedPendingSeen?: boolean;
        };
        trackedWindow.__recentlyArchivedPendingSeen = false;
        const observer = new MutationObserver(() => {
          if (document.querySelector('[data-testid^="sidebar-archived-pending-"]')) {
            trackedWindow.__recentlyArchivedPendingSeen = true;
            observer.disconnect();
          }
        });
        observer.observe(document.body, { childList: true, subtree: true });
      });

      await archiveWorkspaceFromSidebar(page, workspace.workspaceId);

      await expect(liveRow).toHaveCount(0, { timeout: 30_000 });
      await expect(
        page.getByTestId("sidebar-archived-row").filter({
          hasText: "Archive transition workspace",
        }),
      ).toBeVisible({ timeout: 30_000 });
      await expect.poll(() => wasRecentlyArchivedPendingSeen(page)).toBe(true);
      await expect(pendingRow).toHaveCount(0);

      await page.getByText("Archive transition workspace", { exact: true }).hover();
      await restoreButton.click();

      await expect(liveRow).toBeVisible({ timeout: 30_000 });
      await expect(
        page
          .getByTestId("sidebar-archived-row")
          .getByText("Archive transition workspace", { exact: true }),
      ).toHaveCount(0);
    } finally {
      await workspace.cleanup();
    }
  });
});
