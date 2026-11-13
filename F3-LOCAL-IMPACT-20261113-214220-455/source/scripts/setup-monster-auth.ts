import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { randomBytes, scryptSync } from "node:crypto";

function readHidden(prompt: string): Promise<string> {
  const stdin = process.stdin;
  if (!stdin.isTTY || typeof stdin.setRawMode !== "function") {
    throw new Error("Run this setup script in an interactive PowerShell terminal.");
  }

  return new Promise((resolveInput, reject) => {
    let value = "";
    process.stdout.write(prompt);
    stdin.setRawMode(true);
    stdin.resume();

    const cleanup = () => {
      stdin.removeListener("data", onData);
      stdin.setRawMode(false);
      stdin.pause();
      process.stdout.write("\n");
    };

    const onData = (chunk: Buffer | string) => {
      const input = chunk.toString("utf8");
      for (const character of input) {
        if (character === "\u0003") {
          cleanup();
          reject(new Error("Setup cancelled."));
          return;
        }
        if (character === "\r" || character === "\n") {
          cleanup();
          resolveInput(value);
          return;
        }
        if (character === "\u0008" || character === "\u007f") {
          const chars = Array.from(value);
          if (chars.length > 0) {
            chars.pop();
            value = chars.join("");
            process.stdout.write("\b \b");
          }
          continue;
        }
        if (character >= " ") {
          value += character;
          process.stdout.write("*");
        }
      }
    };

    stdin.on("data", onData);
  });
}

async function main() {
  const password = await readHidden("Create administrator password (minimum 4 characters): ");
  if (password.length < 4 || password.length > 1_024) {
    throw new Error("Password must contain between 4 and 1024 characters.");
  }

  const confirmation = await readHidden("Confirm administrator password: ");
  if (password !== confirmation) {
    throw new Error("The passwords do not match. No environment file was changed.");
  }

  const salt = randomBytes(32);
  const passwordKey = scryptSync(password, salt, 64, {
    N: 16_384,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  const passwordHash = `scrypt$${salt.toString("hex")}$${passwordKey.toString("hex")}`;
  const authSecret = randomBytes(48).toString("hex");

  const projectRoot = process.cwd();
  const envPath = join(projectRoot, ".env.local");
  const userRoot = resolve(projectRoot, "..", "..");
  const backupRoot = join(userRoot, "MONSTER-AI-BACKUPS");
  const backupPath = join(
    backupRoot,
    `API-SECURITY-ENV-${new Date().toISOString().replace(/[:.]/g, "-")}.env.local`,
  );

  mkdirSync(backupRoot, { recursive: true });
  if (existsSync(envPath)) {
    mkdirSync(dirname(backupPath), { recursive: true });
    copyFileSync(envPath, backupPath);
  }

  const existing = existsSync(envPath)
    ? readFileSync(envPath, "utf8").replace(/^\uFEFF/, "")
    : "";
  const managedKeys = new Set([
    "MONSTER_AUTH_SECRET",
    "MONSTER_ADMIN_PASSWORD_HASH",
    "MONSTER_COOKIE_SECURE",
  ]);
  const preservedLines = existing
    .split(/\r?\n/)
    .filter((line) => {
      const match = line.match(/^\s*([A-Z0-9_]+)\s*=/);
      return !match || !managedKeys.has(match[1]);
    });
  while (preservedLines.length > 0 && preservedLines[preservedLines.length - 1] === "") {
    preservedLines.pop();
  }

  const managed = [
    `MONSTER_AUTH_SECRET=${authSecret}`,
    `MONSTER_ADMIN_PASSWORD_HASH=${passwordHash.replace(/\$/g, "\\$")}`,
    // The supplied app is local HTTP. Set true only after HTTPS is configured.
    "MONSTER_COOKIE_SECURE=false",
  ];
  const output = [...preservedLines, "", ...managed, ""].join("\n");
  writeFileSync(envPath, output, { encoding: "utf8", mode: 0o600 });

  console.log("\nMONSTER AI administrator authentication configured.");
  console.log("Password: stored as a scrypt hash; not written in plaintext.");
  console.log("Session secret: generated and stored in .env.local.");
  console.log("Cookie mode: local HTTP (HttpOnly + SameSite=Strict; Secure=false).");
  if (existsSync(backupPath)) console.log(`Previous .env.local backup: ${backupPath}`);
  console.log("Restart the Next.js server to load the new environment variables.");
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Authentication setup failed.");
  process.exitCode = 1;
});
