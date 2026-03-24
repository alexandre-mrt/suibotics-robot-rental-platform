import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useActiveRentals, useEndRental } from "../hooks/useRental.js";
import WalletGuard from "../components/WalletGuard.js";
import RentalTimer from "../components/RentalTimer.js";
import CommandPanel from "../components/CommandPanel.js";

// NOTE: In production, the Ed25519 key pair would be generated client-side
// and the private key stored securely (e.g., in session storage or hardware key).
// This demo uses a placeholder — user should provide their key pair.
const DEMO_PRIVATE_KEY = "0000000000000000000000000000000000000000000000000000000000000001";
const DEMO_PUBLIC_KEY = "4cb5abf6ad79fbf5abbccafcc269d85cd2651ed4b885b5869f241aedf0a5ba29";

export default function ActiveRental() {
  const account = useCurrentAccount();
  const { data: rentals, isLoading } = useActiveRentals();
  const endRental = useEndRental();
  const [ending, setEnding] = useState(false);

  const myRental = rentals?.find(
    (r) => r.renter === account?.address && r.isActive
  );

  async function handleEndRental() {
    if (!myRental) return;
    setEnding(true);
    try {
      await endRental.mutateAsync(myRental.id);
    } finally {
      setEnding(false);
    }
  }

  return (
    <WalletGuard message="Connect wallet to view your active rental.">
      <div className="max-w-2xl">
        <h1 className="text-3xl font-bold text-gray-100 mb-8">Active Rental</h1>

        {isLoading && (
          <div className="flex items-center justify-center py-24">
            <div className="animate-spin h-8 w-8 border-2 border-blue-500 border-t-transparent rounded-full" />
          </div>
        )}

        {!isLoading && !myRental && (
          <div className="text-center py-24 text-gray-500">
            <p className="text-lg">No active rental found.</p>
            <p className="text-sm mt-2">
              Browse robots and start a rental to control them here.
            </p>
          </div>
        )}

        {myRental && (
          <div className="space-y-4">
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
              <dl className="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <dt className="text-gray-500">Robot ID</dt>
                  <dd className="font-mono text-gray-300 truncate">
                    {myRental.robotId}
                  </dd>
                </div>
                <div>
                  <dt className="text-gray-500">Escrowed</dt>
                  <dd className="text-blue-400 font-medium">
                    {(BigInt(myRental.escrowedAmount) / 1_000_000_000n).toString()} TREAT
                  </dd>
                </div>
              </dl>
            </div>

            <RentalTimer
              startTime={myRental.startTime}
              maxDurationMs={myRental.maxDurationMs}
            />

            <CommandPanel
              rentalId={myRental.id}
              robotId={myRental.robotId}
              privateKeyHex={DEMO_PRIVATE_KEY}
              publicKeyHex={DEMO_PUBLIC_KEY}
            />

            <button
              onClick={handleEndRental}
              disabled={ending || endRental.isPending}
              className="w-full bg-red-700 hover:bg-red-600 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl px-6 py-4 font-medium transition-colors"
            >
              {ending || endRental.isPending ? "Ending rental..." : "End Rental & Collect Refund"}
            </button>

            {endRental.isError && (
              <p className="text-sm text-red-400">{endRental.error.message}</p>
            )}
          </div>
        )}
      </div>
    </WalletGuard>
  );
}
