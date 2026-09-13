import styles from "./lid-demo.module.css";

type Key = string | readonly [label: string, width: number];
const rows: readonly (readonly Key[])[] = [
  [["esc", 1.4], "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "⏻"],
  ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "−", "=", ["delete", 1.6]],
  [["tab", 1.5], "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", ["\\", 1.1]],
  [["caps lock", 1.8], "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "′", ["return", 1.8]],
  [["shift", 2.3], "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", ["shift", 2.3]],
  ["fn", "control", "option", ["⌘", 1.3], ["", 5.4], ["⌘", 1.3], "option", "←", "arrows", "→"],
];

export function MacKeyboard() {
  return <div className={styles.keyboard} aria-hidden="true">
    {rows.map((row, rowIndex) => <div className={styles.keyRow} key={rowIndex}>
      {row.map((key, index) => {
        const [label, width] = typeof key === "string" ? [key, 1] : key;
        return <span className={styles.key} data-key={label} style={{ flexGrow: width }} key={index}>
          {label === "arrows" ? <><span>↑</span><span>↓</span></> : <span>{label}</span>}
        </span>;
      })}
    </div>)}
  </div>;
}
