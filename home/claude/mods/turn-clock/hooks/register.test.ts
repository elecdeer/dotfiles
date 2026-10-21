import { expect, mock, test } from 'claude-code/testing'

import { formatElapsed, formatStamp } from './format'

test('formatElapsed drops leading zero units', () => {
  expect(formatElapsed(3_000)).toBe('3s')
  expect(formatElapsed(303_000)).toBe('5m 3s')
  expect(formatElapsed(3_723_000)).toBe('1h 2m 3s')
})

test('formatStamp omits the elapsed clause for the first message', () => {
  expect(formatStamp(0, undefined)).not.toContain('since')
  expect(formatStamp(60_000, 0)).toContain('1m 0s since the previous message.')
})

test('every prompt carries a stamp, the second with the elapsed time', async ($, on) => {
  const clock = mock.clock(on, { now: Date.UTC(2026, 9, 21, 5, 0, 0) })
  let seen: readonly string[] | undefined
  on('prompt.submit', (_, e) => {
    seen = e.context
    return { text: e.text, context: e.context }
  })

  await $.prompt.submit({ text: 'first' })
  expect(seen?.[0]).toContain('[turn-clock] Current time:')
  expect(seen?.[0]).not.toContain('since')

  await clock.advance(303_000)
  await $.prompt.submit({ text: 'second' })
  expect(seen?.[0]).toContain('5m 3s since the previous message.')
})
