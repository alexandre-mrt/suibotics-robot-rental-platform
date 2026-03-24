import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import * as ed from "@noble/ed25519";

const API_BASE = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

const COMMANDS: { id: number; label: string; description: string }[] = [
  { id: 1, label: "Move Forward", description: "Move robot forward" },
  { id: 2, label: "Move Back", description: "Move robot backward" },
  { id: 3, label: "Grab", description: "Activate grabber" },
  { id: 4, label: "Release", description: "Release grabber" },
  { id: 5, label: "Scan", description: "Initiate area scan" },
];

interface CommandPanelProps {
  rentalId: string;
  robotId: string;
  privateKeyHex: string;
  publicKeyHex: string;
}

interface ChallengeResponse {
  challenge: string;
  transactionBytes: string;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export default function CommandPanel({
  rentalId,
  robotId,
  privateKeyHex,
  publicKeyHex,
}: CommandPanelProps) {
  const account = useCurrentAccount();
  const [status, setStatus] = useState<string | null>(null);
  const [executing, setExecuting] = useState(false);

  async function executeCommand(commandId: number) {
    if (!account) return;
    setExecuting(true);
    setStatus(null);

    try {
      // Step 1: Request challenge
      const challengeRes = await fetch(`${API_BASE}/commands/challenge`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ walletAddress: account.address }),
      });

      const challengeJson: ApiResponse<ChallengeResponse> = await challengeRes.json();
      if (!challengeJson.success || !challengeJson.data) {
        throw new Error(challengeJson.error ?? "Failed to get challenge");
      }

      // Step 2: Sign the challenge with Ed25519 private key
      const challengeBytes = hexToBytes(challengeJson.data.challenge);
      const privKeyBytes = hexToBytes(privateKeyHex);
      const signature = await ed.signAsync(challengeBytes, privKeyBytes);

      // Step 3: Submit signed command
      const execRes = await fetch(`${API_BASE}/commands/execute`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          walletAddress: account.address,
          rentalId,
          robotId,
          command: commandId,
          publicKey: publicKeyHex,
          signature: bytesToHex(signature),
        }),
      });

      const execJson: ApiResponse<{ transactionBytes: string }> =
        await execRes.json();
      if (!execJson.success) {
        throw new Error(execJson.error ?? "Command execution failed");
      }

      setStatus(`Command ${commandId} authorized.`);
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setExecuting(false);
    }
  }

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
      <h3 className="text-lg font-semibold mb-4">Command Panel</h3>

      <div className="grid grid-cols-2 gap-3 mb-4">
        {COMMANDS.map((cmd) => (
          <button
            key={cmd.id}
            onClick={() => executeCommand(cmd.id)}
            disabled={executing}
            className="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg px-4 py-3 text-sm font-medium transition-colors text-left"
          >
            <span className="block font-semibold">{cmd.label}</span>
            <span className="block text-blue-200 text-xs mt-0.5">
              {cmd.description}
            </span>
          </button>
        ))}
      </div>

      {status && (
        <p
          className={`text-sm rounded px-3 py-2 ${
            status.includes("authorized")
              ? "bg-green-900 text-green-300"
              : "bg-red-900 text-red-300"
          }`}
        >
          {status}
        </p>
      )}

      {executing && (
        <p className="text-sm text-gray-400 mt-2">Signing and submitting...</p>
      )}
    </div>
  );
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  const bytes = new Uint8Array(clean.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
