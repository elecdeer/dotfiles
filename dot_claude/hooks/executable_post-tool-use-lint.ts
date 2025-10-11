#!/usr/bin/env -S deno run --quiet --allow-env --allow-read --allow-run
import { defineHook, runHook } from "npm:cc-hooks-ts";

// Session start hook
const sessionHook = defineHook({
  trigger: {
    PostToolUse: {
      Edit: true,
      MultiEdit: true,
      Write: true,
    },
  },
  run: async (context) => {
    const cwd = context.input.cwd;
    const { default: packageJson } = await import(`${cwd}/package.json`, {
      with: { type: "json" },
    });

    if (!(packageJson.scripts && packageJson.scripts["lint:fix"])) {
      // 何もしない
      return context.success();
    }

    // pnpm-lock.yamlが存在するかどうかでパッケージマネージャーを判断
    let packageManager = "npm";
    try {
      await Deno.stat(`${cwd}/pnpm-lock.yaml`);
      packageManager = "pnpm";
    } catch {
      // pnpm-lock.yamlが存在しない場合はnpmを使用
    }

    // agent:lint:fixみたいな方が良い？
    const command = new Deno.Command(packageManager, {
      args: ["run", "lint:fix"],
      cwd,
    });

    const { code, stdout, stderr } = await command.output();

    if (code === 0) {
      return context.success({
        messageForUser: new TextDecoder().decode(stdout),
      });
    } else {
      return context.blockingError(
        `Linting failed:\n${new TextDecoder().decode(stderr)}`
      );
    }
  },
});

await runHook(sessionHook);
