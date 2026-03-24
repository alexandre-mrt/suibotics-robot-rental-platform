import { useRentalReceipts } from "../hooks/useRental.js";
import WalletGuard from "../components/WalletGuard.js";

function formatDate(timestamp: number): string {
  return new Date(timestamp).toLocaleString();
}

function formatDuration(ms: number): string {
  const totalMinutes = Math.floor(ms / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function formatTreat(raw: string): string {
  const value = BigInt(raw);
  const whole = value / 1_000_000_000n;
  const decimals = (value % 1_000_000_000n).toString().padStart(9, "0").slice(0, 2);
  return `${whole}.${decimals} TREAT`;
}

export default function RentalHistory() {
  return (
    <WalletGuard message="Connect wallet to view your rental history.">
      <RentalHistoryContent />
    </WalletGuard>
  );
}

function RentalHistoryContent() {
  const { data: receipts, isLoading, error } = useRentalReceipts();

  return (
    <div>
      <h1 className="text-3xl font-bold text-gray-100 mb-8">Rental History</h1>

      {isLoading && (
        <div className="flex items-center justify-center py-24">
          <div className="animate-spin h-8 w-8 border-2 border-blue-500 border-t-transparent rounded-full" />
        </div>
      )}

      {error && (
        <div className="bg-red-900 border border-red-700 rounded-xl p-4 text-red-300">
          {error.message}
        </div>
      )}

      {receipts && receipts.length === 0 && (
        <div className="text-center py-24 text-gray-500">
          <p className="text-lg">No rental receipts yet.</p>
          <p className="text-sm mt-2">Complete a rental to earn a receipt NFT.</p>
        </div>
      )}

      {receipts && receipts.length > 0 && (
        <div className="space-y-3">
          {receipts.map((receipt) => (
            <div
              key={receipt.id}
              className="bg-gray-900 border border-gray-800 rounded-xl p-5"
            >
              <div className="flex items-start justify-between mb-3">
                <div>
                  <p className="text-sm text-gray-500 mb-1">Receipt NFT</p>
                  <p className="font-mono text-xs text-gray-400">{receipt.id}</p>
                </div>
                <span className="text-blue-400 font-semibold text-sm">
                  {formatTreat(receipt.totalCost)}
                </span>
              </div>

              <dl className="grid grid-cols-3 gap-3 text-sm">
                <div>
                  <dt className="text-gray-500">Robot</dt>
                  <dd className="font-mono text-xs text-gray-300 truncate">
                    {receipt.robotId}
                  </dd>
                </div>
                <div>
                  <dt className="text-gray-500">Duration</dt>
                  <dd className="text-gray-300">{formatDuration(receipt.durationMs)}</dd>
                </div>
                <div>
                  <dt className="text-gray-500">Date</dt>
                  <dd className="text-gray-300 text-xs">{formatDate(receipt.timestamp)}</dd>
                </div>
              </dl>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
