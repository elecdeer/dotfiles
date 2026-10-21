import type { Register } from 'claude-code'

import { formatStamp } from './format'

export const register: Register = on => {
  // Kept in the module, not `$.state`: a new session has no previous message,
  // and a reload only costs one missing "since" clause.
  let previous: number | undefined

  on('prompt.submit', async ($, e, next) => {
    const now = await $.clock.now()
    const stamp = formatStamp(now, previous)
    previous = now

    return next({ ...e, context: [...(e.context ?? []), stamp] })
  })
}
