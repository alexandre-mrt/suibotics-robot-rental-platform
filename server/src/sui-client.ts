import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import type {
  RobotInfo,
  RentalAgreement,
  RentalReceipt,
  SuiClientConfig,
} from "./types.js";

const DEFAULT_CONFIG: SuiClientConfig = {
  rpcUrl: process.env["SUI_RPC_URL"] ?? getFullnodeUrl("testnet"),
  packageId: process.env["PACKAGE_ID"] ?? "0x0",
  registryObjectId: process.env["REGISTRY_OBJECT_ID"] ?? "0x0",
  escrowObjectId: process.env["ESCROW_OBJECT_ID"] ?? "0x0",
  commandAuthObjectId: process.env["COMMAND_AUTH_OBJECT_ID"] ?? "0x0",
  faucetObjectId: process.env["FAUCET_OBJECT_ID"] ?? "0x0",
};

export class RobotRentalSuiClient {
  readonly client: SuiClient;
  readonly config: SuiClientConfig;

  constructor(config: Partial<SuiClientConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.client = new SuiClient({ url: this.config.rpcUrl });
  }

  async getRobots(): Promise<RobotInfo[]> {
    // Query RobotRegistered events to build robot list
    const events = await this.client.queryEvents({
      query: {
        MoveEventType: `${this.config.packageId}::robot_registry::RobotRegistered`,
      },
      limit: 50,
    });

    const robots: RobotInfo[] = [];

    for (const event of events.data) {
      const parsed = event.parsedJson as {
        robot_id: string;
        owner: string;
        name: string;
        hourly_rate: string;
      } | undefined;

      if (!parsed) continue;

      // Fetch current state from dynamic field or object
      const robotInfo = await this.getRobotById(parsed.robot_id).catch(
        () => null
      );
      if (robotInfo) robots.push(robotInfo);
    }

    return robots;
  }

  async getRobotById(robotId: string): Promise<RobotInfo | null> {
    // Fetch robot info from registry dynamic field
    try {
      const field = await this.client.getDynamicFieldObject({
        parentId: this.config.registryObjectId,
        name: { type: "0x2::object::ID", value: robotId },
      });

      if (!field.data?.content || field.data.content.dataType !== "moveObject") {
        return null;
      }

      const fields = field.data.content.fields as {
        name: string;
        capabilities: number[];
        hourly_rate: string;
        owner: string;
        is_available: boolean;
        total_rentals: string;
        total_earned: string;
      };

      return {
        id: robotId,
        name: fields.name,
        capabilities: fields.capabilities,
        hourlyRate: fields.hourly_rate,
        owner: fields.owner,
        isAvailable: fields.is_available,
        totalRentals: Number(fields.total_rentals),
        totalEarned: fields.total_earned,
      };
    } catch {
      return null;
    }
  }

  async getActiveRentals(): Promise<RentalAgreement[]> {
    const events = await this.client.queryEvents({
      query: {
        MoveEventType: `${this.config.packageId}::rental_escrow::RentalCreated`,
      },
      limit: 50,
    });

    const rentals: RentalAgreement[] = [];

    for (const event of events.data) {
      const parsed = event.parsedJson as {
        rental_id: string;
        robot_id: string;
        renter: string;
        max_duration_ms: string;
        escrowed_amount: string;
      } | undefined;

      if (!parsed) continue;

      const rental = await this.getRentalById(parsed.rental_id).catch(
        () => null
      );
      if (rental?.isActive) rentals.push(rental);
    }

    return rentals;
  }

  async getRentalById(rentalId: string): Promise<RentalAgreement | null> {
    try {
      const field = await this.client.getDynamicFieldObject({
        parentId: this.config.escrowObjectId,
        name: { type: "0x2::object::ID", value: rentalId },
      });

      if (!field.data?.content || field.data.content.dataType !== "moveObject") {
        return null;
      }

      const fields = field.data.content.fields as {
        renter: string;
        robot_id: string;
        start_time: string;
        max_duration_ms: string;
        hourly_rate: string;
        escrowed_amount: string;
        is_active: boolean;
      };

      return {
        id: rentalId,
        renter: fields.renter,
        robotId: fields.robot_id,
        startTime: Number(fields.start_time),
        maxDurationMs: Number(fields.max_duration_ms),
        hourlyRate: fields.hourly_rate,
        escrowedAmount: fields.escrowed_amount,
        isActive: fields.is_active,
      };
    } catch {
      return null;
    }
  }

  async getReceiptsByAddress(address: string): Promise<RentalReceipt[]> {
    const objects = await this.client.getOwnedObjects({
      owner: address,
      filter: {
        StructType: `${this.config.packageId}::rental_escrow::RentalReceipt`,
      },
      options: { showContent: true },
    });

    const receipts: RentalReceipt[] = [];

    for (const obj of objects.data) {
      if (!obj.data?.content || obj.data.content.dataType !== "moveObject") continue;

      const fields = obj.data.content.fields as {
        robot_id: string;
        renter: string;
        duration_ms: string;
        total_cost: string;
        timestamp: string;
      };

      receipts.push({
        id: obj.data.objectId,
        robotId: fields.robot_id,
        renter: fields.renter,
        durationMs: Number(fields.duration_ms),
        totalCost: fields.total_cost,
        timestamp: Number(fields.timestamp),
      });
    }

    return receipts;
  }

  buildCreateRentalTx(
    robotId: string,
    durationHours: number,
    paymentCoinId: string
  ): Transaction {
    const tx = new Transaction();
    const clockObj = tx.object("0x6");

    tx.moveCall({
      target: `${this.config.packageId}::rental_escrow::create_rental`,
      arguments: [
        tx.object(this.config.escrowObjectId),
        tx.object(this.config.registryObjectId),
        tx.pure.id(robotId),
        tx.pure.u64(durationHours),
        tx.object(paymentCoinId),
        clockObj,
      ],
    });

    return tx;
  }

  buildEndRentalTx(rentalCapId: string): Transaction {
    const tx = new Transaction();
    const clockObj = tx.object("0x6");

    tx.moveCall({
      target: `${this.config.packageId}::rental_escrow::end_rental`,
      arguments: [
        tx.object(this.config.escrowObjectId),
        tx.object(this.config.registryObjectId),
        tx.object(rentalCapId),
        clockObj,
      ],
    });

    return tx;
  }

  buildRequestChallengeTx(): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.config.packageId}::command_auth::request_challenge`,
      arguments: [tx.object(this.config.commandAuthObjectId)],
    });

    return tx;
  }

  buildVerifyAndExecuteTx(
    rentalCapId: string,
    publicKey: Uint8Array,
    signature: Uint8Array,
    command: number
  ): Transaction {
    const tx = new Transaction();
    const clockObj = tx.object("0x6");

    tx.moveCall({
      target: `${this.config.packageId}::command_auth::verify_and_execute`,
      arguments: [
        tx.object(this.config.commandAuthObjectId),
        tx.object(this.config.escrowObjectId),
        tx.object(rentalCapId),
        tx.pure.vector("u8", Array.from(publicKey)),
        tx.pure.vector("u8", Array.from(signature)),
        tx.pure.u8(command),
        clockObj,
      ],
    });

    return tx;
  }
}
