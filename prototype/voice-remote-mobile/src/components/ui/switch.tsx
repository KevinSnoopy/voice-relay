import { cn } from '../../lib/utils'

interface SwitchProps {
  checked: boolean
  onChange: (next: boolean) => void
  label: string
  className?: string
}

/** 48dp 触控目标的自定义开关，避免额外依赖 */
export function Switch({ checked, onChange, label, className }: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      className={cn(
        'relative inline-flex h-8 w-[52px] shrink-0 items-center rounded-full border transition-colors duration-200 focus-visible:ring-2 focus-visible:ring-blue-400/60 focus-visible:ring-offset-2 outline-none',
        checked ? 'border-blue-600 bg-blue-600' : 'border-slate-300 bg-slate-200',
        className,
      )}
    >
      <span
        className={cn(
          'inline-block h-6 w-6 transform rounded-full bg-white shadow transition-transform duration-200',
          checked ? 'translate-x-[22px]' : 'translate-x-[3px]',
        )}
      />
    </button>
  )
}
