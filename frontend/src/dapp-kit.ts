import { getFullnodeUrl } from "@mysten/sui/client";
import { createNetworkConfig } from "@mysten/dapp-kit";

const { networkConfig, useNetworkVariable } = createNetworkConfig({
  testnet: {
    url: getFullnodeUrl("testnet"),
    variables: {
      packageId: import.meta.env.VITE_PACKAGE_ID ?? "0x0",
      registryObjectId: import.meta.env.VITE_REGISTRY_OBJECT_ID ?? "0x0",
      escrowObjectId: import.meta.env.VITE_ESCROW_OBJECT_ID ?? "0x0",
      commandAuthObjectId: import.meta.env.VITE_COMMAND_AUTH_OBJECT_ID ?? "0x0",
      faucetObjectId: import.meta.env.VITE_FAUCET_OBJECT_ID ?? "0x0",
    },
  },
});

export { networkConfig, useNetworkVariable };
