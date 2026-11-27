import { ArrowDownToLine, KeyRound, Laptop2, Link2Off, Loader2, MicOff, Send, WifiOff } from 'lucide-react'
import { cn } from '../lib/utils'

export type ConnState = 'connected' | 'listening' | 'recognizing' | 'success' | 'submitted' | 'failed' | 'disconnected'

export interface StatusBarProps {
  state: ConnState
  macName: string
  backend?: 'local' | 'ime'
  timer?: string
  warnTimer?: boolean
  onOpenPanel?: () => void
  className?: string
}

const STATE_META: Record<
  ConnState,
  { label: string; dot: string; text: string; chip: string; icon: React.ReactNode }
> = {
  connected: {
    label: '已连接',
    dot: 'bg-emerald-500',
    text: 'text-emerald-700',
    chip: 'bg-emerald-50 border-emerald-200',
    icon: <Link2Off className="h-3 w-3" />,
  },
  listening: {
    label: '正在收音',
    dot: 'bg-rose-500 animate-pulse',
    text: 'text-rose-700',
    chip: 'bg-rose-50 border-rose-200',
    icon: <MicOff className="h-3 w-3" />,
  },
  recognizing: {
    label: '正在识别',
    dot: 'bg-blue-500',
    text: 'text-blue-700',
    chip: 'bg-blue-50 border-blue-200',
    icon: <Loader2 className="h-3 w-3" />,
  },
  success: {
    label: '已上屏',
    dot: 'bg-emerald-500',
    text: 'text-emerald-700',
    chip: 'bg-emerald-50 border-emerald-200',
    icon: <ArrowDownToLine className="h-3 w-3" />,
  },
  submitted: {
    label: '已发送到输入法',
    dot: 'bg-blue-500',
    text: 'text-blue-700',
    chip: 'bg-blue-50 border-blue-200',
    icon: <Send className="h-3 w-3" />,
  },
  failed: {
    label: '上屏失败',
    dot: 'bg-amber-500',
    text: 'text-amber-700',
    chip: 'bg-amber-50 border-amber-200',
    icon: <KeyRound className="h-3 w-3" />,
  },
  disconnected: {
    label: '未连接',
    dot: 'bg-slate-400',
    text: 'text-slate-600',
    chip: 'bg-slate-100 border-slate-200',
    icon: <WifiOff className="h-3 w-3" />,
  },
}

/** 顶部状态条（高 44）：圆点 + Mac 名称 + 后端标识，状态不只靠颜色 */
export function StatusBar({
  state,
  macName,
  backend = 'local',
  timer,
  warnTimer,
  onOpenPanel,
  className,
}: StatusBarProps) {
  const meta = STATE_META[state]
  return (
    <div
      className={cn('flex h-11 shrink-0 items-center gap-2 px-4', className)}
      role="status"
      aria-live="polite"
    >
      <div
        className={cn(
          'flex items-center gap-2 rounded-full border px-2.5 py-1 transition-colors duration-200',
          meta.chip,
        )}
      >
        <span className={cn('h-2 w-2 rounded-full transition-colors duration-200', meta.dot)} />
        <span className={cn('text-[11px] font-semibold transition-colors duration-200', meta.text)}>
          {meta.label}
        </span>
      </div>
      <div className="flex min-w-0 flex-1 items-center gap-1.5">
        <Laptop2 className="h-3.5 w-3.5 shrink-0 text-slate-400" />
        <span className="truncate text-xs font-medium text-slate-700">{macName}</span>
      </div>
      {timer ? (
        <span
          className={cn(
            'rounded-md px-1.5 py-0.5 text-xs font-semibold tabular-nums transition-colors duration-200',
            warnTimer ? 'bg-amber-100 text-amber-800' : 'bg-slate-100 text-slate-700',
          )}
        >
          {timer}
        </span>
      ) : null}
      <span
        className={cn(
          'rounded-md px-1.5 py-0.5 text-[11px] font-medium',
          backend === 'local'
            ? 'bg-slate-100 text-slate-600'
            : 'bg-indigo-50 text-indigo-700 ring-1 ring-indigo-200',
        )}
        title={backend === 'local' ? '本地识别' : '输入法通道'}
      >
        {backend === 'local' ? '本地' : '输入法'}
      </span>
      {onOpenPanel ? (
        <button
          type="button"
          onClick={onOpenPanel}
          aria-label="打开控制面板"
          className="ml-0.5 grid h-9 w-9 place-items-center rounded-lg text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-800"
        >
          <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden>
            <path d="M2 9l5-5 5 5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
      ) : null}
    </div>
  )
}
