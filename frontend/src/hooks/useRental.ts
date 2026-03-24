import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";

const API_BASE = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

export interface RentalAgreement {
  id: string;
  renter: string;
  robotId: string;
  startTime: number;
  maxDurationMs: number;
  hourlyRate: string;
  escrowedAmount: string;
  isActive: boolean;
}

export interface RentalReceipt {
  id: string;
  robotId: string;
  renter: string;
  durationMs: number;
  totalCost: string;
  timestamp: number;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

interface CreateRentalResponse {
  transactionBytes: string;
}

async function fetchActiveRentals(): Promise<RentalAgreement[]> {
  const res = await fetch(`${API_BASE}/rentals/active`);
  const json: ApiResponse<RentalAgreement[]> = await res.json();
  if (!json.success || !json.data) throw new Error(json.error ?? "Failed to fetch rentals");
  return json.data;
}

async function fetchReceipts(address: string): Promise<RentalReceipt[]> {
  const res = await fetch(`${API_BASE}/receipts/${address}`);
  const json: ApiResponse<RentalReceipt[]> = await res.json();
  if (!json.success || !json.data) throw new Error(json.error ?? "Failed to fetch receipts");
  return json.data;
}

export function useActiveRentals() {
  return useQuery({
    queryKey: ["rentals", "active"],
    queryFn: fetchActiveRentals,
    staleTime: 15_000,
  });
}

export function useRentalReceipts() {
  const account = useCurrentAccount();

  return useQuery({
    queryKey: ["receipts", account?.address],
    queryFn: () => fetchReceipts(account!.address),
    enabled: !!account?.address,
    staleTime: 30_000,
  });
}

export function useCreateRental() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  return useMutation({
    mutationFn: async ({
      robotId,
      durationHours,
      walletAddress,
    }: {
      robotId: string;
      durationHours: number;
      walletAddress: string;
    }) => {
      const res = await fetch(`${API_BASE}/rentals`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ robotId, durationHours, walletAddress }),
      });

      const json: ApiResponse<CreateRentalResponse> = await res.json();
      if (!json.success || !json.data) {
        throw new Error(json.error ?? "Failed to create rental");
      }

      // Pass base64 string directly — dapp-kit accepts string | Transaction
      return signAndExecute({ transaction: json.data.transactionBytes });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["robots"] });
      queryClient.invalidateQueries({ queryKey: ["rentals"] });
    },
  });
}

export function useEndRental() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  return useMutation({
    mutationFn: async (rentalCapId: string) => {
      const res = await fetch(`${API_BASE}/rentals/${rentalCapId}/end`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });

      const json: ApiResponse<CreateRentalResponse> = await res.json();
      if (!json.success || !json.data) {
        throw new Error(json.error ?? "Failed to end rental");
      }

      return signAndExecute({ transaction: json.data.transactionBytes });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["robots"] });
      queryClient.invalidateQueries({ queryKey: ["rentals"] });
      queryClient.invalidateQueries({ queryKey: ["receipts"] });
    },
  });
}
