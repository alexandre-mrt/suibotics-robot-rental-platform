import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useRobot } from "../hooks/useRobots.js";
import { useCreateRental } from "../hooks/useRental.js";
import WalletGuard from "../components/WalletGuard.js";

const CAPABILITY_LABELS: Record<number, string> = {
  1: "Move",
  2: "Grab",
  3: "Scan",
  4: "Weld",
  5: "Inspect",
};

function formatTreat(raw: string): string {
  const value = BigInt(raw);
  const whole = value / 1_000_000_000n;
  return `${whole} TREAT`;
}

export default function RobotDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const account = useCurrentAccount();
  const { data: robot, isLoading, error } = useRobot(id);
  const createRental = useCreateRental();
  const [durationHours, setDurationHours] = useState(1);

  async function handleRent() {
    if (!account || !robot) return;
    await createRental.mutateAsync({
      robotId: robot.id,
      durationHours,
      walletAddress: account.address,
    });
    navigate("/rental/active");
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="animate-spin h-8 w-8 border-2 border-blue-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  if (error || !robot) {
    return (
      <div className="bg-red-900 border border-red-700 rounded-xl p-4 text-red-300">
        {error?.message ?? "Robot not found"}
      </div>
    );
  }

  const totalCost = BigInt(robot.hourlyRate) * BigInt(durationHours);

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-100 mb-2">{robot.name}</h1>
        <span
          className={`text-sm px-3 py-1 rounded-full font-medium ${
            robot.isAvailable
              ? "bg-green-900 text-green-300"
              : "bg-red-900 text-red-300"
          }`}
        >
          {robot.isAvailable ? "Available" : "Currently Rented"}
        </span>
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 mb-6">
        <dl className="grid grid-cols-2 gap-4">
          <div>
            <dt className="text-sm text-gray-500">Hourly Rate</dt>
            <dd className="text-lg font-semibold text-blue-400">
              {formatTreat(robot.hourlyRate)}/hr
            </dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Total Rentals</dt>
            <dd className="text-lg font-semibold">{robot.totalRentals}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Capabilities</dt>
            <dd className="flex flex-wrap gap-1 mt-1">
              {robot.capabilities.map((cap) => (
                <span
                  key={cap}
                  className="text-xs bg-gray-800 text-gray-300 px-2 py-0.5 rounded"
                >
                  {CAPABILITY_LABELS[cap] ?? `CMD-${cap}`}
                </span>
              ))}
            </dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Owner</dt>
            <dd className="text-sm font-mono text-gray-400 truncate">
              {robot.owner}
            </dd>
          </div>
        </dl>
      </div>

      {robot.isAvailable && (
        <WalletGuard message="Connect wallet to rent this robot.">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <h2 className="text-lg font-semibold mb-4">Rent This Robot</h2>

            <div className="mb-4">
              <label
                htmlFor="duration"
                className="block text-sm text-gray-400 mb-2"
              >
                Duration (hours)
              </label>
              <input
                id="duration"
                type="number"
                min={1}
                max={24}
                value={durationHours}
                onChange={(e) =>
                  setDurationHours(Math.max(1, Number(e.target.value)))
                }
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-gray-100 focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="flex items-center justify-between mb-4 p-3 bg-gray-800 rounded-lg">
              <span className="text-sm text-gray-400">Total Cost</span>
              <span className="font-semibold text-blue-400">
                {formatTreat(totalCost.toString())} TREAT
              </span>
            </div>

            <button
              onClick={handleRent}
              disabled={createRental.isPending}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg px-6 py-3 font-medium transition-colors"
            >
              {createRental.isPending ? "Processing..." : "Rent Now"}
            </button>

            {createRental.isError && (
              <p className="mt-3 text-sm text-red-400">
                {createRental.error.message}
              </p>
            )}
          </div>
        </WalletGuard>
      )}
    </div>
  );
}
