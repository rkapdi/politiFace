import { useSyncExternalStore } from 'react'

// Two themes over one set of role tokens (see styles.css). The choice is
// a device preference, so it lives in this browser only: nothing about it
// is stored with the account.
export type Theme = 'dark' | 'light'

const KEY = 'pf-theme'
const listeners = new Set<() => void>()

function read(): Theme {
  return document.documentElement.dataset.theme === 'light' ? 'light' : 'dark'
}

export function setTheme(theme: Theme) {
  document.documentElement.dataset.theme = theme
  try {
    localStorage.setItem(KEY, theme)
  } catch {
    // Private windows can refuse storage; the theme still applies for this visit.
  }
  listeners.forEach(fn => fn())
}

function subscribe(fn: () => void) {
  listeners.add(fn)
  return () => {
    listeners.delete(fn)
  }
}

/** The current theme and a setter. index.html applies the saved one before first paint. */
export function useTheme(): [Theme, (theme: Theme) => void] {
  return [useSyncExternalStore(subscribe, read, () => 'dark' as Theme), setTheme]
}
