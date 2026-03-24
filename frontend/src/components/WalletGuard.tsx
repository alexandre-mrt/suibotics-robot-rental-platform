import { useCurrentAccount } from "@mysten/dapp-kit";
import { ConnectButton } from "@mysten/dapp-kit";
import type { ReactNode } from "react";

interface WalletGuardProps {
  children: ReactNode;
  message?: string;
}

export default function WalletGuard({
  children,
  message = "Connect your wallet to continue.",
}: WalletGuardProps) {
  const account = useCurrentAccount();

  if (!account) {
    return (
      <div className="flex flex-col items-center justify-center py-24 gap-4">
        <p className="text-gray-400 text-lg">{message}</p>
        <ConnectButton />
      </div>
    );
  }

  return <>{children}</>;
}
