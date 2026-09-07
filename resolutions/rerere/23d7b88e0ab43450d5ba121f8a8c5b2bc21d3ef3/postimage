import { beforeEach, describe, expect, it, vi } from "vitest";

const nativeModule = vi.hoisted(() => ({
  begin: vi.fn(async () => undefined),
  end: vi.fn(async () => undefined),
  getAudioRoutes: vi.fn(async () => ({
    active: { id: "android:1", label: "Pixel Buds", kind: "earbuds" },
    candidates: [{ id: "android:1", label: "Pixel Buds", kind: "earbuds" }],
  })),
  setAudioRoute: vi.fn(async () => true),
  setWearNodeNames: vi.fn(async () => undefined),
  addListener: vi.fn(() => ({ remove: vi.fn() })),
}));

const expoModules = vi.hoisted(() => ({
  requireOptionalNativeModule: vi.fn<() => unknown>(() => null),
}));

vi.mock("expo-modules-core", () => expoModules);

import {
  beginLiveVoiceBackgroundCall,
  endLiveVoiceBackgroundCall,
  getLiveVoiceAudioRoutes,
  isLiveVoiceBackgroundCallSupported,
  setLiveVoiceAudioRoute,
  setLiveVoiceWearNodeNames,
  subscribeLiveVoiceAudioRoutes,
} from "./background-call-lifetime.native";

describe("native background-call lifetime", () => {
  beforeEach(() => {
    expoModules.requireOptionalNativeModule.mockReset();
    expoModules.requireOptionalNativeModule.mockReturnValue(null);
    nativeModule.begin.mockClear();
    nativeModule.end.mockClear();
    nativeModule.getAudioRoutes.mockClear();
    nativeModule.setAudioRoute.mockClear();
    nativeModule.setWearNodeNames.mockClear();
    nativeModule.addListener.mockClear();
  });

  it("exposes communication routes and route changes when Android supports them", async () => {
    expoModules.requireOptionalNativeModule.mockReturnValue(nativeModule);
    const listener = vi.fn();

    expect(await getLiveVoiceAudioRoutes()).toMatchObject({
      active: { label: "Pixel Buds", kind: "earbuds" },
    });
    expect(await setLiveVoiceAudioRoute("android:1")).toBe(true);
    await setLiveVoiceWearNodeNames(["Pixel Watch 3"]);
    const unsubscribe = subscribeLiveVoiceAudioRoutes(listener);
    unsubscribe();

    expect(nativeModule.setAudioRoute).toHaveBeenCalledWith("android:1");
    expect(nativeModule.setWearNodeNames).toHaveBeenCalledWith(["Pixel Watch 3"]);
    expect(nativeModule.addListener).toHaveBeenCalledWith(
      "onBackgroundCallAudioRouteChanged",
      listener,
    );
  });

  it("reports background mode as unsupported when the app binary lacks the module", async () => {
    expect(expoModules.requireOptionalNativeModule).not.toHaveBeenCalled();
    expect(isLiveVoiceBackgroundCallSupported()).toBe(false);

    await expect(beginLiveVoiceBackgroundCall()).rejects.toThrow(
      "Live Voice background mode is unavailable in this app binary",
    );
    expect(expoModules.requireOptionalNativeModule).toHaveBeenCalledTimes(2);
  });

  it("delegates lifetime ownership when the native module is installed", async () => {
    expoModules.requireOptionalNativeModule.mockReturnValue(nativeModule);

    expect(isLiveVoiceBackgroundCallSupported()).toBe(true);
    await beginLiveVoiceBackgroundCall();
    await endLiveVoiceBackgroundCall();

    expect(nativeModule.begin).toHaveBeenCalledOnce();
    expect(nativeModule.end).toHaveBeenCalledOnce();
  });
});
