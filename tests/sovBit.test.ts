import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const contractName = "sovBit";
const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const ROLE_ADMIN = 1n;
const ROLE_TREASURER = 2n;
const ROLE_MEMBER = 3n;
const VOTING_PERIOD = 144;

function unwrapOkUint(result: any): bigint {
  expect(result).toBeOk(expect.anything());
  return result.value.value as bigint;
}

function unwrapSome(result: any) {
  expect(result).toBeSome(expect.anything());
  return result.value;
}

function mineBlocks(count: number) {
  for (let i = 0; i < count; i += 1) {
    simnet.mineBlock([]);
  }
}

function createDao(name = "SovBit DAO", supply = 1000n) {
  const create = simnet.callPublicFn(
    contractName,
    "create-dao",
    [Cl.stringUtf8(name), Cl.uint(supply)],
    deployer,
  );
  return unwrapOkUint(create.result);
}

describe("sovBit core flows", () => {
  it("creates a DAO with defaults", () => {
    const daoId = createDao();

    const dao = simnet.callReadOnlyFn(contractName, "get-dao", [Cl.uint(daoId)], deployer);
    expect(dao.result).toBeSome(
      Cl.tuple({
        name: Cl.stringUtf8("SovBit DAO"),
        admin: Cl.standardPrincipal(deployer),
        "total-members": Cl.uint(1),
        "token-supply": Cl.uint(1000),
      }),
    );

    const treasury = simnet.callReadOnlyFn(contractName, "get-treasury", [Cl.uint(daoId)], deployer);
    expect(treasury.result).toBeUint(0);

    const role = simnet.callReadOnlyFn(
      contractName,
      "get-member-role",
      [Cl.uint(daoId), Cl.standardPrincipal(deployer)],
      deployer,
    );
    expect(role.result).toBeUint(ROLE_ADMIN);

    const config = simnet.callReadOnlyFn(
      contractName,
      "get-treasury-config",
      [Cl.uint(daoId)],
      deployer,
    );
    expect(config.result).toBeSome(
      Cl.tuple({
        "required-signatures": Cl.uint(2),
        "max-single-withdrawal": Cl.uint(1000000),
        "daily-withdrawal-limit": Cl.uint(5000000),
        "emergency-multisig-required": Cl.uint(3),
      }),
    );

    const nextId = simnet.callReadOnlyFn(contractName, "get-next-dao-id", [], deployer);
    expect(nextId.result).toBeUint(daoId + 1n);
  });

  it("transfers tokens and adds a new member", () => {
    const daoId = createDao("Transfer DAO", 1000n);

    const transfer = simnet.callPublicFn(
      contractName,
      "transfer-token",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1), Cl.uint(150)],
      deployer,
    );
    expect(transfer.result).toBeOk(Cl.bool(true));

    const senderBal = simnet.callReadOnlyFn(
      contractName,
      "get-balance",
      [Cl.uint(daoId), Cl.standardPrincipal(deployer)],
      deployer,
    );
    expect(senderBal.result).toBeUint(850);

    const receiverBal = simnet.callReadOnlyFn(
      contractName,
      "get-balance",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect(receiverBal.result).toBeUint(150);

    const dao = simnet.callReadOnlyFn(contractName, "get-dao", [Cl.uint(daoId)], deployer);
    expect(dao.result).toBeSome(
      Cl.tuple({
        name: Cl.stringUtf8("Transfer DAO"),
        admin: Cl.standardPrincipal(deployer),
        "total-members": Cl.uint(2),
        "token-supply": Cl.uint(1000),
      }),
    );

    const role = simnet.callReadOnlyFn(
      contractName,
      "get-member-role",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1)],
      deployer,
    );
    expect(role.result).toBeUint(ROLE_MEMBER);
  });

  it("passes and executes a treasury proposal", () => {
    const daoId = createDao("Governance DAO", 1000n);

    const transfer = simnet.callPublicFn(
      contractName,
      "transfer-token",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1), Cl.uint(100)],
      deployer,
    );
    expect(transfer.result).toBeOk(Cl.bool(true));

    const deposit = simnet.callPublicFn(
      contractName,
      "deposit-treasury",
      [Cl.uint(daoId), Cl.uint(1000)],
      deployer,
    );
    expect(deposit.result).toBeOk(Cl.bool(true));

    const submit = simnet.callPublicFn(
      contractName,
      "submit-enhanced-proposal",
      [
        Cl.uint(daoId),
        Cl.stringUtf8("Fund Ops"),
        Cl.stringUtf8("Allocate treasury funds"),
        Cl.stringAscii("treasury"),
        Cl.some(Cl.uint(500)),
        Cl.some(Cl.standardPrincipal(wallet2)),
      ],
      wallet1,
    );
    const proposalId = unwrapOkUint(submit.result);

    const vote = simnet.callPublicFn(
      contractName,
      "vote-enhanced-proposal",
      [Cl.uint(daoId), Cl.uint(proposalId), Cl.bool(true)],
      wallet1,
    );
    expect(vote.result).toBeOk(Cl.uint(100));

    mineBlocks(VOTING_PERIOD + 1);

    const state = simnet.callReadOnlyFn(
      contractName,
      "get-proposal-state",
      [Cl.uint(daoId), Cl.uint(proposalId)],
      deployer,
    );
    expect(state.result).toBeAscii("passed");

    const execute = simnet.callPublicFn(
      contractName,
      "execute-enhanced-proposal",
      [Cl.uint(daoId), Cl.uint(proposalId)],
      deployer,
    );
    expect(execute.result).toBeOk(Cl.stringAscii("treasury-proposal-created"));

    const nextTx = simnet.callReadOnlyFn(contractName, "get-next-tx-id", [], deployer);
    const txId = (nextTx.result as any).value - 1n;

    const pending = simnet.callReadOnlyFn(
      contractName,
      "get-pending-transaction",
      [Cl.uint(daoId), Cl.uint(txId)],
      deployer,
    );
    const txData = unwrapSome(pending.result);
    expect(txData.value.amount).toBeUint(500);
    expect(txData.value.recipient).toBePrincipal(wallet2);
    expect(txData.value.purpose).toBeUtf8("Proposal execution");
    expect(txData.value["current-sigs"]).toBeUint(0);
    expect(txData.value["required-sigs"]).toBeUint(2);
    expect(txData.value.executed).toBeBool(false);
    expect(txData.value["tx-type"]).toBeAscii("withdrawal");
  });

  it("executes a multisig withdrawal after signatures", () => {
    const daoId = createDao("Treasury DAO", 1000n);

    const transfer = simnet.callPublicFn(
      contractName,
      "transfer-token",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1), Cl.uint(100)],
      deployer,
    );
    expect(transfer.result).toBeOk(Cl.bool(true));

    const assign = simnet.callPublicFn(
      contractName,
      "assign-role",
      [Cl.uint(daoId), Cl.standardPrincipal(wallet1), Cl.uint(ROLE_TREASURER)],
      deployer,
    );
    expect(assign.result).toBeOk(Cl.bool(true));

    const deposit = simnet.callPublicFn(
      contractName,
      "deposit-treasury",
      [Cl.uint(daoId), Cl.uint(1000)],
      deployer,
    );
    expect(deposit.result).toBeOk(Cl.bool(true));

    const request = simnet.callPublicFn(
      contractName,
      "request-withdrawal",
      [
        Cl.uint(daoId),
        Cl.uint(300),
        Cl.standardPrincipal(wallet2),
        Cl.stringUtf8("Ops budget"),
      ],
      deployer,
    );
    const txId = unwrapOkUint(request.result);

    const sign1 = simnet.callPublicFn(
      contractName,
      "sign-transaction",
      [Cl.uint(daoId), Cl.uint(txId)],
      deployer,
    );
    expect(sign1.result).toBeOk(Cl.bool(true));

    const sign2 = simnet.callPublicFn(
      contractName,
      "sign-transaction",
      [Cl.uint(daoId), Cl.uint(txId)],
      wallet1,
    );
    expect(sign2.result).toBeOk(Cl.bool(true));

    const pending = simnet.callReadOnlyFn(
      contractName,
      "get-pending-transaction",
      [Cl.uint(daoId), Cl.uint(txId)],
      deployer,
    );
    const txData = unwrapSome(pending.result);
    expect(txData.value.executed).toBeBool(true);
    expect(txData.value["current-sigs"]).toBeUint(2);

    const treasury = simnet.callReadOnlyFn(contractName, "get-treasury", [Cl.uint(daoId)], deployer);
    expect(treasury.result).toBeUint(700);

    const today = BigInt(Math.floor(simnet.blockHeight / 144));
    const daily = simnet.callReadOnlyFn(
      contractName,
      "get-daily-withdrawn",
      [Cl.uint(daoId), Cl.uint(today)],
      deployer,
    );
    expect(daily.result).toBeUint(300);
  });
});
