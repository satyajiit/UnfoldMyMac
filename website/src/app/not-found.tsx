import Link from "next/link";
import { Button } from "@/components/ui/button";
export default function NotFound() { return <div className="container not-found"><span className="muted">404</span><h1>This page has left the stage.</h1><p>Head back to the collection and find something worth opening.</p><Button asChild><Link href="/">Back to UnfoldMyMac</Link></Button></div>; }
