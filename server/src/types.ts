export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

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

export interface CreateRentalRequest {
  robotId: string;
  durationHours: number;
  walletAddress: string;
}

export interface EndRentalRequest {
  walletAddress: string;
}

export interface ChallengeRequest {
  walletAddress: string;
}

export interface ChallengeResponse {
  challenge: string;
  nonce: number;
}

export interface ExecuteCommandRequest {
  walletAddress: string;
  rentalId: string;
  robotId: string;
  command: number;
  publicKey: string;
  signature: string;
}

export interface SuiClientConfig {
  rpcUrl: string;
  packageId: string;
  registryObjectId: string;
  escrowObjectId: string;
  commandAuthObjectId: string;
  faucetObjectId: string;
}
