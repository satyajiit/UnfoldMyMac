"use client";
import { ThemeProvider, useTheme } from "next-themes";
import { useSyncExternalStore } from "react";
import { Monitor, Moon, Sun } from "lucide-react";
const subscribe = () => () => {};
export function Theme({ children }: { children: React.ReactNode }) {
  return <ThemeProvider attribute="class" defaultTheme="system" enableSystem storageKey="unfoldmymac.theme" disableTransitionOnChange>{children}</ThemeProvider>;
}
export function ThemeControl() {
  const { theme, setTheme } = useTheme();
  const mounted = useSyncExternalStore(subscribe, () => true, () => false);
  return <div className="theme-control" role="group" aria-label="Appearance">
    {([{ value: "system", Icon: Monitor }, { value: "light", Icon: Sun }, { value: "dark", Icon: Moon }]).map(({ value, Icon }) =>
      <button key={value} type="button" aria-label={`${value[0].toUpperCase()}${value.slice(1)} appearance`} aria-pressed={mounted && theme === value} onClick={() => setTheme(value)} title={`${value} appearance`}><Icon size={16} aria-hidden="true" /></button>)}
  </div>;
}
