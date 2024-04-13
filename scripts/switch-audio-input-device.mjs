#!/usr/bin/env zx

// 自動でマイクデバイスを切り替えるスクリプト
// $ zx switch-audio-input-device.mjs "デバイス名1" "デバイス名2" ...
// 引数順は優先順位になる
// SwitchAudioSourceをhomebrewでインストールしておく必要がある

const inputDevicesRaw =
  await $`/opt/homebrew/bin/SwitchAudioSource -a -f json -t input`;
const inputDevices = inputDevicesRaw.stdout.split("\n").map((line) => {
  if (!line) return;
  return JSON.parse(line);
});

const priorityDevices = process.argv.slice(2);
const searchSwitchDevice = () => {
  for (const device of inputDevices) {
    if (priorityDevices.includes(device.name)) {
      return device;
    }
  }
  return null;
};

const switchDevice = searchSwitchDevice();
if (switchDevice === null) {
  console.log("No device found");
  process.exit(1);
}
await $`/opt/homebrew/bin/SwitchAudioSource -t input -s ${switchDevice.name}`;
console.log(`Switched to ${switchDevice.name}`);
