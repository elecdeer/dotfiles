#!/usr/bin/env -S deno run --quiet --allow-env --allow-read --allow-run
import { defineHook, runHook } from "npm:cc-hooks-ts";
import { join, resolve } from "jsr:@std/path";

const stopHook = defineHook({
  trigger: {
    Stop: true,
  },
  run: async (context) => {
    const transcriptPath = context.input.transcript_path;

    if (!transcriptPath) {
      return context.success();
    }

    const homeDir = Deno.env.get("HOME");
    if (!homeDir) {
      return context.success();
    }

    // ~/を展開
    let resolvedTranscriptPath = transcriptPath;
    if (transcriptPath.startsWith("~/")) {
      resolvedTranscriptPath = join(homeDir, transcriptPath.slice(2));
    }

    // セキュリティチェック: 許可されたパス配下か確認
    const allowedBase = join(homeDir, ".claude", "projects");
    const absolutePath = resolve(resolvedTranscriptPath);

    if (!absolutePath.startsWith(allowedBase)) {
      return context.blockingError(
        "Transcript path is not in allowed directory"
      );
    }

    // ファイルが存在するか確認
    try {
      await Deno.stat(absolutePath);
    } catch {
      return context.success();
    }

    // トランスクリプトファイルを読み込み
    const content = await Deno.readTextFile(absolutePath);
    const lines = content.split("\n").filter((line) => line.trim());

    if (lines.length === 0) {
      return context.success();
    }

    // 最後の行をJSONとしてパース
    const lastLine = lines[lines.length - 1];
    const transcript = JSON.parse(lastLine);
    const lastMessageContent = transcript?.message?.content?.[0]?.text;

    if (!lastMessageContent) {
      return context.success();
    }

    // macOSの通知を表示
    const script = `
      on run {notificationTitle, notificationMessage}
        try
          display notification notificationMessage with title notificationTitle sound name "Crystal"
        end try
      end run
    `;

    const command = new Deno.Command("osascript", {
      args: ["-e", script, "Claude Code", lastMessageContent],
    });

    const { code } = await command.output();

    if (code === 0) {
      return context.success();
    } else {
      return context.success(); // 通知の失敗は致命的ではないのでsuccessを返す
    }
  },
});

await runHook(stopHook);
