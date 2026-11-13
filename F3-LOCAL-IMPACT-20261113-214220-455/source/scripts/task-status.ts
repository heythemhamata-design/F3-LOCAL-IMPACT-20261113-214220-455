import { loadEnvConfig } from "@next/env";
import { getTaskDetails } from "../lib/tasks/queue";
import { getPostgresPool } from "../lib/db/postgres";

loadEnvConfig(process.cwd());

async function main() {
  const id = process.argv[2];
  if (!id) throw new Error("Usage: npm run task:status -- <task-uuid>");

  try {
    const task = await getTaskDetails(id);
    if (!task) {
      console.log("TASK NOT FOUND");
      return;
    }
    console.log(JSON.stringify(task, null, 2));
  } finally {
    await getPostgresPool().end();
  }
}

main().catch((error) => {
  console.error(`TASK STATUS FAILED: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
