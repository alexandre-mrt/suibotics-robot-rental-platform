import { Link } from "react-router-dom";
import type { RobotInfo } from "../hooks/useRobots.js";

const CAPABILITY_LABELS: Record<number, string> = {
  1: "Move",
  2: "Grab",
  3: "Scan",
  4: "Weld",
  5: "Inspect",
};

interface RobotCardProps {
  robot: RobotInfo;
}

function formatTreat(raw: string): string {
  const value = BigInt(raw);
  const whole = value / 1_000_000_000n;
  return `${whole} TREAT/hr`;
}

export default function RobotCard({ robot }: RobotCardProps) {
  return (
    <Link
      to={`/robots/${robot.id}`}
      className="block bg-gray-900 border border-gray-800 rounded-xl p-5 hover:border-blue-500 transition-colors"
    >
      <div className="flex items-start justify-between mb-3">
        <h3 className="text-lg font-semibold text-gray-100">{robot.name}</h3>
        <span
          className={`text-xs px-2 py-1 rounded-full font-medium ${
            robot.isAvailable
              ? "bg-green-900 text-green-300"
              : "bg-red-900 text-red-300"
          }`}
        >
          {robot.isAvailable ? "Available" : "Rented"}
        </span>
      </div>

      <p className="text-blue-400 font-medium text-sm mb-3">
        {formatTreat(robot.hourlyRate)}
      </p>

      <div className="flex flex-wrap gap-1 mb-3">
        {robot.capabilities.map((cap) => (
          <span
            key={cap}
            className="text-xs bg-gray-800 text-gray-400 px-2 py-0.5 rounded"
          >
            {CAPABILITY_LABELS[cap] ?? `CMD-${cap}`}
          </span>
        ))}
      </div>

      <p className="text-xs text-gray-600">
        {robot.totalRentals} rental{robot.totalRentals !== 1 ? "s" : ""} completed
      </p>
    </Link>
  );
}
