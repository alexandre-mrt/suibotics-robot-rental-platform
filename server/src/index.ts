import { RobotRentalSuiClient } from "./sui-client.js";
import type {
  ApiResponse,
  RobotInfo,
  RentalAgreement,
  RentalReceipt,
  CreateRentalRequest,
  ChallengeResponse,
  ExecuteCommandRequest,
} from "./types.js";

const PORT = Number(process.env["PORT"] ?? 3001);
const suiClient = new RobotRentalSuiClient();

function json<T>(data: ApiResponse<T>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function notFound(): Response {
  return json<null>({ success: false, error: "Not found" }, 404);
}

function badRequest(message: string): Response {
  return json<null>({ success: false, error: message }, 400);
}

function serverError(message: string): Response {
  return json<null>({ success: false, error: message }, 500);
}

async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;

  try {
    // GET /robots
    if (method === "GET" && path === "/robots") {
      const robots = await suiClient.getRobots();
      return json<RobotInfo[]>({ success: true, data: robots });
    }

    // GET /robots/:id
    const robotDetailMatch = path.match(/^\/robots\/([^/]+)$/);
    if (method === "GET" && robotDetailMatch) {
      const robotId = robotDetailMatch[1];
      if (!robotId) return badRequest("Missing robot ID");
      const robot = await suiClient.getRobotById(robotId);
      if (!robot) return notFound();
      return json<RobotInfo>({ success: true, data: robot });
    }

    // POST /rentals
    if (method === "POST" && path === "/rentals") {
      const body = (await req.json()) as Partial<CreateRentalRequest>;

      if (!body.robotId || !body.durationHours || !body.walletAddress) {
        return badRequest("Missing required fields: robotId, durationHours, walletAddress");
      }

      if (body.durationHours < 1) {
        return badRequest("durationHours must be at least 1");
      }

      // Build transaction — caller must sign and submit via wallet
      const tx = suiClient.buildCreateRentalTx(
        body.robotId,
        body.durationHours,
        "" // paymentCoinId must be provided by wallet client
      );

      const txBytes = await tx.build({ client: suiClient.client });

      return json<{ transactionBytes: string }>({
        success: true,
        data: { transactionBytes: Buffer.from(txBytes).toString("base64") },
      });
    }

    // POST /rentals/:id/end
    const endRentalMatch = path.match(/^\/rentals\/([^/]+)\/end$/);
    if (method === "POST" && endRentalMatch) {
      const rentalCapId = endRentalMatch[1];
      if (!rentalCapId) return badRequest("Missing rental cap ID");

      const tx = suiClient.buildEndRentalTx(rentalCapId);
      const txBytes = await tx.build({ client: suiClient.client });

      return json<{ transactionBytes: string }>({
        success: true,
        data: { transactionBytes: Buffer.from(txBytes).toString("base64") },
      });
    }

    // POST /commands/challenge
    if (method === "POST" && path === "/commands/challenge") {
      const body = (await req.json()) as { walletAddress?: string };

      if (!body.walletAddress) {
        return badRequest("Missing walletAddress");
      }

      const tx = suiClient.buildRequestChallengeTx();
      const txBytes = await tx.build({ client: suiClient.client });

      return json<ChallengeResponse & { transactionBytes: string }>({
        success: true,
        data: {
          challenge: "",
          nonce: 0,
          transactionBytes: Buffer.from(txBytes).toString("base64"),
        },
      });
    }

    // POST /commands/execute
    if (method === "POST" && path === "/commands/execute") {
      const body = (await req.json()) as Partial<ExecuteCommandRequest>;

      if (
        !body.walletAddress ||
        !body.rentalId ||
        !body.robotId ||
        body.command === undefined ||
        !body.publicKey ||
        !body.signature
      ) {
        return badRequest(
          "Missing required fields: walletAddress, rentalId, robotId, command, publicKey, signature"
        );
      }

      if (body.command < 0 || body.command > 255) {
        return badRequest("command must be a value between 0 and 255");
      }

      const publicKey = Buffer.from(body.publicKey, "hex");
      const signature = Buffer.from(body.signature, "hex");

      const tx = suiClient.buildVerifyAndExecuteTx(
        body.rentalId,
        publicKey,
        signature,
        body.command
      );
      const txBytes = await tx.build({ client: suiClient.client });

      return json<{ transactionBytes: string }>({
        success: true,
        data: { transactionBytes: Buffer.from(txBytes).toString("base64") },
      });
    }

    // GET /rentals/active
    if (method === "GET" && path === "/rentals/active") {
      const rentals = await suiClient.getActiveRentals();
      return json<RentalAgreement[]>({ success: true, data: rentals });
    }

    // GET /receipts/:address
    const receiptsMatch = path.match(/^\/receipts\/([^/]+)$/);
    if (method === "GET" && receiptsMatch) {
      const address = receiptsMatch[1];
      if (!address) return badRequest("Missing address");

      const receipts = await suiClient.getReceiptsByAddress(address);
      return json<RentalReceipt[]>({ success: true, data: receipts });
    }

    return notFound();
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return serverError(message);
  }
}

const server = Bun.serve({
  port: PORT,
  fetch: handleRequest,
});

console.log(`Robot Rental API running on http://localhost:${server.port}`);
