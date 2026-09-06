import { Fragment } from "react";
import { View } from "react-native";
import { StyleSheet } from "react-native-unistyles";
import { settingsStyles } from "@/styles/settings";
import { CodexBankedResetManagement } from "./banked-resets";
import { ProviderUsageCard } from "./card";
import type { ProviderUsage, ProviderUsagePercentageDisplay } from "./types";

export function ProviderUsageList({
  providers,
  percentageDisplay,
  serverId,
}: {
  providers: ProviderUsage[];
  serverId: string;
  percentageDisplay: ProviderUsagePercentageDisplay;
}) {
  return (
    <View style={settingsStyles.card}>
      {providers.map((usage, index) => (
        <Fragment key={usage.providerId}>
          {index > 0 ? <View style={styles.divider} /> : null}
          <ProviderUsageCard usage={usage} percentageDisplay={percentageDisplay}>
            {usage.providerId === "codex" ? (
              <CodexBankedResetManagement serverId={serverId} resets={usage.bankedResets} />
            ) : null}
          </ProviderUsageCard>
        </Fragment>
      ))}
    </View>
  );
}

const styles = StyleSheet.create((theme) => ({
  divider: {
    height: 1,
    backgroundColor: theme.colors.border,
  },
}));
