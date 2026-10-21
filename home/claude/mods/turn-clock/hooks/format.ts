const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const

/**
 * Zero-pads a number to two digits.
 */
const pad = (n: number): string => String(n).padStart(2, '0')

/**
 * Formats a duration as `1h 2m 3s`, omitting leading zero units.
 */
export const formatElapsed = (ms: number): string => {
  const total = Math.max(0, Math.round(ms / 1000))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const seconds = total % 60

  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`
  if (minutes > 0) return `${minutes}m ${seconds}s`
  return `${seconds}s`
}

/**
 * Formats an epoch in the host's local time zone, e.g. `2026-10-21 (Wed) 14:03:12 +09:00`.
 */
export const formatLocal = (epochMs: number): string => {
  const d = new Date(epochMs)
  const offset = -d.getTimezoneOffset()
  const sign = offset >= 0 ? '+' : '-'
  const abs = Math.abs(offset)
  const date = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  const time = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`

  return `${date} (${WEEKDAYS[d.getDay()]}) ${time} ${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`
}

/**
 * Builds the context block attached to a prompt: the current time and, when
 * there was a previous message, how long ago it was.
 */
export const formatStamp = (now: number, previous: number | undefined): string => {
  const since =
    previous === undefined
      ? ''
      : ` ${formatElapsed(now - previous)} since the previous message.`

  return `[turn-clock] Current time: ${formatLocal(now)}.${since}`
}
