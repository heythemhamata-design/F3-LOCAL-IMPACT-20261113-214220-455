import { loadEnvConfig } from "@next/env";
import { cancelPendingTask } from "../lib/tasks/queue";
import { getPostgresPool } from "../lib/db/postgres";

loadEnvConfig(process.cwd());

async function main() {
  const id = process.argv[2];
  if (!id) throw new Error("Usage: npm run task:cancel -- <task-uuid>");

  try {
    const cancelled = await cancelPendingTask(id);
    if (cancelled) {
      console.log(`TASK CANCELLED: ${id}`);
    } else {
      console.log("Task was not found or is no longer pending. Running tasks are not force-cancelled in V1.");
    }
  } finally {
    await getPostgresPool().end();
  }
}

main().catch((error) => {
  console.error(`TASK CANCEL FAILED: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
