import styles from "./lid-demo.module.css";

export function MacStickers() {
  return <svg className={styles.sticker} viewBox="0 0 100 110" aria-hidden="true" focusable="false">
    <rect x="1" y="1" width="98" height="108" rx="9" fill="#e5eaf0" stroke="#f8fbff" strokeWidth="2" />
    <rect x="5" y="5" width="90" height="100" rx="6" fill="#086caa" />
    <path d="M12 8H87Q92 8 92 14V30L8 77V14Q8 8 12 8Z" fill="#ffffff" opacity=".07" />
    <path d="M15 56C6 37 28 19 58 18C83 17 96 30 89 49M86 71C75 90 30 96 15 77" fill="none" stroke="#fff" strokeWidth="3" strokeLinecap="round" />
    <text x="50" y="54" textAnchor="middle" fill="#fff" fontFamily="Arial, sans-serif" fontSize="32" fontWeight="700" fontStyle="italic" letterSpacing="-1.5">intel</text>
    <text x="50" y="74" textAnchor="middle" fill="#fff" fontFamily="Arial, sans-serif" fontSize="17" fontWeight="700">outside</text>
  </svg>;
}
