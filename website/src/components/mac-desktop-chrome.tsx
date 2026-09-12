import Image from "next/image";
import { BatteryFull, Compass, Folder, MessageCircle, Music2, Search, Settings2, Terminal, Trash2, Wifi } from "lucide-react";
import styles from "./lid-demo.module.css";

export function MacDesktopChrome() {
  return <div className={styles.desktopChrome} aria-hidden="true">
    <div className={styles.menuBar}><span className={styles.menuApp}>◈</span><strong>Finder</strong><span>File</span><span>Edit</span><span>View</span><span>Go</span><span className={styles.menuSpacer} /><Wifi /><BatteryFull /><Search /><span>9:41</span></div>
    <div className={styles.dock} data-mac-dock="true">
      <span className={styles.dockBlue}><Folder /></span><span className={styles.dockWhite}><Compass /></span><span className={styles.dockBlack}><Terminal /></span><span className={styles.dockGreen}><MessageCircle /></span><span className={styles.dockPink}><Music2 /></span><span className={styles.dockGray}><Settings2 /></span><span className={styles.dockApp}><Image src="/media/logo.webp" alt="" width={48} height={48} /></span><i /><span className={styles.dockGray}><Trash2 /></span>
    </div>
  </div>;
}
