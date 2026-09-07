import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
/* oxlint-disable no-restricted-imports */
import {
  Text,
  View,
  type NativeSyntheticEvent,
  type PointerEvent,
  type StyleProp,
  type TextInputKeyPressEventData,
  type TextStyle,
} from "react-native";
/* oxlint-enable no-restricted-imports */
import { StyleSheet } from "react-native-unistyles";
import {
  EditingTextInput as TextInput,
  type EditingTextInputHandle,
} from "@/components/ui/text-input";
import { isWeb } from "@/constants/platform";
import { useToast } from "@/contexts/toast-context";

const DOUBLE_CLICK_INTERVAL_MS = 500;

type InlineRenameState =
  | { kind: "idle" }
  | { kind: "editing"; draft: string }
  | { kind: "saving"; draft: string };

interface SidebarWorkspaceInlineTitleProps {
  displayValue: string;
  renameValue: string;
  editable: boolean;
  onSubmit?: (value: string) => Promise<void>;
  style: StyleProp<TextStyle>;
  testID: string;
}

export function SidebarWorkspaceInlineTitle({
  displayValue,
  renameValue,
  editable,
  onSubmit,
  style,
  testID,
}: SidebarWorkspaceInlineTitleProps) {
  const { t } = useTranslation();
  const toast = useToast();
  const [state, setState] = useState<InlineRenameState>({ kind: "idle" });
  const inputRef = useRef<EditingTextInputHandle>(null);
  const titleRef = useRef<View>(null);
  const cancelledRef = useRef(false);
  const submittingRef = useRef(false);
  const lastTitlePointerDownAtRef = useRef<number | null>(null);

  // The row wraps this title in a Pressable, and React Native Web's press
  // responder stops `pointerdown` before it reaches React's root delegate — a
  // `View`-level `onPointerDown` prop never fires from real input. Listen on
  // the node itself, in the capture phase, where the event still arrives.
  useEffect(() => {
    if (!isWeb || !editable || state.kind !== "idle") {
      return;
    }
    const node = titleRef.current as unknown as HTMLElement | null;
    if (!node) {
      return;
    }

    const handleTitlePointerDown = (event: globalThis.PointerEvent) => {
      const previousPointerDownAt = lastTitlePointerDownAtRef.current;
      lastTitlePointerDownAtRef.current = event.timeStamp;
      if (
        previousPointerDownAt === null ||
        event.timeStamp - previousPointerDownAt > DOUBLE_CLICK_INTERVAL_MS
      ) {
        return;
      }

      // Keep the second click from reaching the row's press handler.
      event.stopPropagation();
      event.preventDefault();
      lastTitlePointerDownAtRef.current = null;
      cancelledRef.current = false;
      setState({ kind: "editing", draft: renameValue });
    };

    node.addEventListener("pointerdown", handleTitlePointerDown, true);
    return () => {
      node.removeEventListener("pointerdown", handleTitlePointerDown, true);
    };
  }, [editable, renameValue, state.kind]);

  const handleChangeText = useCallback((draft: string) => {
    setState({ kind: "editing", draft });
  }, []);

  const submit = useCallback(async () => {
    if (state.kind !== "editing" || !onSubmit || submittingRef.current || cancelledRef.current) {
      return;
    }
    const value = state.draft.trim();
    if (!value) {
      toast.error(t("common.errors.nameRequired"));
      inputRef.current?.focus();
      return;
    }
    if (value === renameValue) {
      setState({ kind: "idle" });
      return;
    }

    submittingRef.current = true;
    setState({ kind: "saving", draft: state.draft });
    try {
      await onSubmit(value);
      setState({ kind: "idle" });
    } catch (error) {
      setState({ kind: "editing", draft: state.draft });
      toast.error(
        error instanceof Error && error.message ? error.message : t("common.errors.unableToSave"),
      );
      requestAnimationFrame(() => inputRef.current?.focus());
    } finally {
      submittingRef.current = false;
    }
  }, [onSubmit, renameValue, state, t, toast]);

  const handleBlur = useCallback(() => {
    void submit();
  }, [submit]);

  const handleSubmitEditing = useCallback(() => {
    void submit();
  }, [submit]);

  const handleKeyPress = useCallback(
    (event: NativeSyntheticEvent<TextInputKeyPressEventData>) => {
      event.stopPropagation();
      if (event.nativeEvent.key !== "Escape" || state.kind === "saving") {
        return;
      }
      cancelledRef.current = true;
      setState({ kind: "idle" });
    },
    [state.kind],
  );

  const handleInputPointerDown = useCallback((event: PointerEvent) => {
    event.stopPropagation();
  }, []);

  if (state.kind !== "idle") {
    return (
      <TextInput
        ref={inputRef}
        autoFocus
        selectTextOnFocus
        editable={state.kind === "editing"}
        initialValue={state.draft}
        onChangeText={handleChangeText}
        onBlur={handleBlur}
        onSubmitEditing={handleSubmitEditing}
        onKeyPress={handleKeyPress}
        onPointerDown={handleInputPointerDown}
        returnKeyType="done"
        style={[style, styles.input]}
        testID={`${testID}-input`}
        accessibilityLabel={t("sidebar.workspace.rename.title")}
      />
    );
  }

  return (
    <View ref={titleRef} style={styles.titleClickTarget} testID={testID}>
      <Text style={style} numberOfLines={1}>
        {displayValue}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create((theme) => ({
  titleClickTarget: {
    flexShrink: 1,
    minWidth: 0,
  },
  input: {
    flex: 1,
    minWidth: 0,
    height: 22,
    paddingVertical: 0,
    paddingHorizontal: theme.spacing[1],
    borderWidth: 1,
    borderColor: theme.colors.border,
    borderRadius: theme.borderRadius.sm,
    backgroundColor: theme.colors.surface0,
  },
}));
