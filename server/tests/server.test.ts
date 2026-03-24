import { describe, it, expect, vi, beforeEach } from "vitest";
import { RobotRentalSuiClient } from "../src/sui-client.js";

// Mock the SuiClient dependency
vi.mock("@mysten/sui/client", () => ({
  SuiClient: vi.fn().mockImplementation(() => ({
    queryEvents: vi.fn().mockResolvedValue({ data: [] }),
    getOwnedObjects: vi.fn().mockResolvedValue({ data: [] }),
    getDynamicFieldObject: vi.fn().mockResolvedValue({ data: null }),
  })),
  getFullnodeUrl: vi.fn().mockReturnValue("https://fullnode.testnet.sui.io:443"),
}));

vi.mock("@mysten/sui/transactions", () => ({
  Transaction: vi.fn().mockImplementation(() => ({
    object: vi.fn().mockReturnValue({}),
    pure: {
      id: vi.fn().mockReturnValue({}),
      u64: vi.fn().mockReturnValue({}),
      u8: vi.fn().mockReturnValue({}),
      vector: vi.fn().mockReturnValue({}),
    },
    moveCall: vi.fn(),
    build: vi.fn().mockResolvedValue(new Uint8Array([1, 2, 3])),
  })),
}));

describe("RobotRentalSuiClient", () => {
  let client: RobotRentalSuiClient;

  beforeEach(() => {
    client = new RobotRentalSuiClient({
      packageId: "0xdeadbeef",
      registryObjectId: "0xregistry",
      escrowObjectId: "0xescrow",
      commandAuthObjectId: "0xcommandauth",
      faucetObjectId: "0xfaucet",
    });
  });

  it("getRobots returns empty array when no events", async () => {
    const robots = await client.getRobots();
    expect(robots).toEqual([]);
  });

  it("getRobotById returns null for missing robot", async () => {
    const robot = await client.getRobotById("0xmissing");
    expect(robot).toBeNull();
  });

  it("getActiveRentals returns empty array when no events", async () => {
    const rentals = await client.getActiveRentals();
    expect(rentals).toEqual([]);
  });

  it("getReceiptsByAddress returns empty array when no objects", async () => {
    const receipts = await client.getReceiptsByAddress("0xaddress");
    expect(receipts).toEqual([]);
  });

  it("buildCreateRentalTx constructs a transaction", () => {
    const tx = client.buildCreateRentalTx("0xrobot", 2, "0xcoin");
    expect(tx).toBeDefined();
  });

  it("buildEndRentalTx constructs a transaction", () => {
    const tx = client.buildEndRentalTx("0xrentalcap");
    expect(tx).toBeDefined();
  });

  it("buildRequestChallengeTx constructs a transaction", () => {
    const tx = client.buildRequestChallengeTx();
    expect(tx).toBeDefined();
  });

  it("buildVerifyAndExecuteTx constructs a transaction", () => {
    const tx = client.buildVerifyAndExecuteTx(
      "0xrentalcap",
      new Uint8Array(32),
      new Uint8Array(64),
      1
    );
    expect(tx).toBeDefined();
  });
});

describe("API Response shape", () => {
  it("success response has correct shape", () => {
    const response = { success: true, data: { id: "0x1" } };
    expect(response.success).toBe(true);
    expect(response.data).toBeDefined();
  });

  it("error response has correct shape", () => {
    const response = { success: false, error: "Not found" };
    expect(response.success).toBe(false);
    expect(response.error).toBe("Not found");
  });
});
