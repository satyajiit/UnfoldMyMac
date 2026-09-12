import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

const buttonVariants = cva("button", { variants: {
  variant: { default: "button-primary", secondary: "button-secondary", ghost: "button-ghost" },
  size: { default: "", small: "button-small", icon: "button-icon" },
}, defaultVariants: { variant: "default", size: "default" } });

export function Button({ asChild = false, className, variant, size, ...props }:
  ComponentProps<"button"> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Component = asChild ? Slot : "button";
  return <Component className={cn(buttonVariants({ variant, size, className }))} {...props} />;
}
