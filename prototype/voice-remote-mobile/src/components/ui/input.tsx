import * as React from 'react'
import { cn } from '../../lib/utils'

export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        'flex h-11 w-full rounded-xl border border-slate-200 bg-white px-3.5 text-sm text-slate-900 placeholder:text-slate-400 outline-none transition-shadow focus-visible:border-blue-400 focus-visible:ring-2 focus-visible:ring-blue-100',
        className,
      )}
      {...props}
    />
  ),
)
Input.displayName = 'Input'
