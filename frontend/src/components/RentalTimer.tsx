import { useState, useEffect } from "react";

interface RentalTimerProps {
  startTime: number;
  maxDurationMs: number;
}

function formatDuration(ms: number): string {
  if (ms <= 0) return "00:00:00";
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return [hours, minutes, seconds]
    .map((n) => String(n).padStart(2, "0"))
    .join(":");
}

export default function RentalTimer({ startTime, maxDurationMs }: RentalTimerProps) {
  const endTime = startTime + maxDurationMs;
  const [remaining, setRemaining] = useState(endTime - Date.now());

  useEffect(() => {
    const interval = setInterval(() => {
      setRemaining(endTime - Date.now());
    }, 1000);

    return () => clearInterval(interval);
  }, [endTime]);

  const elapsed = Date.now() - startTime;
  const progressPct = Math.min(100, (elapsed / maxDurationMs) * 100);
  const isExpired = remaining <= 0;

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-gray-400">Time Remaining</span>
        <span
          className={`font-mono text-2xl font-bold ${
            isExpired ? "text-red-400" : remaining < 600_000 ? "text-yellow-400" : "text-green-400"
          }`}
        >
          {isExpired ? "EXPIRED" : formatDuration(remaining)}
        </span>
      </div>

      <div className="w-full bg-gray-800 rounded-full h-2">
        <div
          className={`h-2 rounded-full transition-all ${
            isExpired ? "bg-red-500" : progressPct > 80 ? "bg-yellow-500" : "bg-blue-500"
          }`}
          style={{ width: `${progressPct}%` }}
        />
      </div>

      <p className="text-xs text-gray-600 mt-2">
        {formatDuration(elapsed)} elapsed of {formatDuration(maxDurationMs)} max
      </p>
    </div>
  );
}
