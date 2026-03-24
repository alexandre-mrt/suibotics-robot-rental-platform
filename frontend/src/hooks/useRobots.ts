import { useQuery } from "@tanstack/react-query";

const API_BASE = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

export interface RobotInfo {
  id: string;
  name: string;
  capabilities: number[];
  hourlyRate: string;
  owner: string;
  isAvailable: boolean;
  totalRentals: number;
  totalEarned: string;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

async function fetchRobots(): Promise<RobotInfo[]> {
  const res = await fetch(`${API_BASE}/robots`);
  const json: ApiResponse<RobotInfo[]> = await res.json();
  if (!json.success || !json.data) throw new Error(json.error ?? "Failed to fetch robots");
  return json.data;
}

async function fetchRobotById(id: string): Promise<RobotInfo> {
  const res = await fetch(`${API_BASE}/robots/${id}`);
  const json: ApiResponse<RobotInfo> = await res.json();
  if (!json.success || !json.data) throw new Error(json.error ?? "Robot not found");
  return json.data;
}

export function useRobots() {
  return useQuery({
    queryKey: ["robots"],
    queryFn: fetchRobots,
    staleTime: 30_000,
  });
}

export function useRobot(id: string | undefined) {
  return useQuery({
    queryKey: ["robot", id],
    queryFn: () => fetchRobotById(id!),
    enabled: !!id,
    staleTime: 30_000,
  });
}
