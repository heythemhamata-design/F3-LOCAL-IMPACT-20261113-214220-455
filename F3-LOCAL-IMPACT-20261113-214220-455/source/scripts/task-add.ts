import { loadEnvConfig } from "@next/env";
import { AGENTS, type AgentId } from "../lib/agents/registry";
import { enqueueTask } from "../lib/tasks/queue";
import { getPostgresPool } from "../lib/db/postgres";

loadEnvConfig(process.cwd());

function readArg(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function readIntArg(name: string, fallback: number): number {
  const raw = readArg(name);
  if (!raw) return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value)) throw new Error(`--${name} must be an integer.`);
  return value;
}

async function main() {
  try {
    const agentId = readArg("agent");
    const taskText = readArg("task");
    const toolsArg = (readArg("tools") ?? "false").toLowerCase();
    const enableTools = toolsArg === "true";
    if (!agentId || !AGENTS.some((agent) => agent.id === agentId)) {
      throw new Error(`Pass --agent with one of: ${AGENTS.map((agent) => agent.id).join(", ")}`);
    }
    if (!taskText) throw new Error('Pass --task "Task description".');
    if (!( ["true", "false"].includes(toolsArg) )) throw new Error("--tools must be true or false.");

    const dependencies = (readArg("depends-on") ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

    const task = await enqueueTask({
      agentId: agentId as AgentId,
      input: taskText,
      enableTools,
      priority: readIntArg("priority", 100),
      maxAttempts: readIntArg("max-attempts", 3),
      dependencies,
    });

    console.log("TASK ENQUEUED");
    console.log(`ID: ${task.id}`);
    console.log(`Agent: ${task.agent_id}`);
    console.log(`Status: ${task.status}`);
    console.log(`Priority: ${task.priority} (lower runs first)`);
    console.log(`Max attempts: ${task.max_attempts}`);
    console.log(`Dependencies: ${task.dependencies.length}`);
    console.log(`Correlation ID: ${task.correlation_id}`);
  } finally {
    await getPostgresPool().end();
  }
}

main().catch((error) => {
  console.error(`TASK ADD FAILED: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
