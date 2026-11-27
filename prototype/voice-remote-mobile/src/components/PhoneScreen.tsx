import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ArrowLeft, LayoutGrid, Moon, Sun } from 'lucide-react'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { MAC_LIST } from '../store/voice'

interface PhoneScreenProps {
  code: string
  title: string
  children: ReactNode
  /** 是否显示底部 Home 指示条（全屏页也可关掉） */
  homeIndicator?: boolean
  /** 屏幕自身背景，如扫码页的全屏深色预览 */
  tone?: 'light' | 'dark'
  /** 是否隐藏内部状态条（自行绘制时） */
  bare?: boolean
  className?: string
}

/** 应用壳：填满父容器，不绘制设备外框；内容区唯一滚动 */
export function PhoneScreen({
  code,
  title,
  children,
  homeIndicator = true,
  tone = 'light',
  bare = false,
  className,
}: PhoneScreenProps) {
  const [dark, setDark] = useState(false)

  return (
    <div
      className={cn(
        'flex h-full min-h-0 w-full flex-col overflow-hidden',
        dark ? 'theme-dark bg-slate-950 text-slate-50' : '',
        className,
      )}
    >
      {!bare && (
        <header className="flex h-12 shrink-0 items-center gap-2 border-b border-slate-200/70 bg-white/85 px-2 backdrop-blur transition-colors dark:border-slate-800 dark:bg-slate-950/80">
          <Link
            to="/"
            aria-label="返回画板索引"
            className="grid h-10 w-10 place-items-center rounded-xl text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white"
          >
            <ArrowLeft className="h-4 w-4" />
          </Link>
          <div className="min-w-0 flex-1 leading-tight">
            <div className="truncate text-sm font-semibold text-slate-900 dark:text-slate-50">
              {title}
            </div>
            <div className="truncate text-[11px] font-medium tracking-wide text-slate-400 dark:text-slate-500">
              {code} · 演示数据 · 语音遥控
            </div>
          </div>
          <button
            type="button"
            onClick={() => setDark((v) => !v)}
            aria-label={dark ? '切换到浅色模式' : '切换到深色模式'}
            className="grid h-10 w-10 place-items-center rounded-xl text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white"
          >
            {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </button>
          <Link
            to="/components"
            aria-label="查看组件页"
            className="grid h-10 w-10 place-items-center rounded-xl text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white"
          >
            <LayoutGrid className="h-4 w-4" />
          </Link>
        </header>
      )}
      <div
        className={cn(
          'relative flex min-h-0 flex-1 flex-col overflow-hidden',
          tone === 'dark' ? 'text-slate-50' : 'text-slate-900',
        )}
      >
        {children}
        {homeIndicator && (
          <div
            aria-hidden
            className={cn(
              'pointer-events-none absolute bottom-1.5 left-1/2 h-1 w-32 -translate-x-1/2 rounded-full',
              tone === 'dark' ? 'bg-white/40' : 'bg-slate-900/25 dark:bg-white/30',
            )}
          />
        )}
      </div>
    </div>
  )
}

/** 列表/卡片区容器：唯一纵向滚动器 */
export function ScrollArea({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn('min-h-0 flex-1 overflow-y-auto no-scrollbar', className)}>{children}</div>
  )
}

export function MacListPreview({ onPick }: { onPick: (name: string) => void }) {
  return (
    <ul className="space-y-2.5">
      {MAC_LIST.map((m) => (
        <li key={m.id}>
          <button
            type="button"
            onClick={() => onPick(m.name)}
            className="flex w-full items-center gap-3 rounded-2xl border border-slate-200 bg-white p-3 text-left transition-all hover:border-blue-200 hover:shadow-md dark:border-slate-700 dark:bg-slate-900 dark:hover:border-blue-500/60"
          >
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-300">
              <LayoutGrid className="h-4 w-4" />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold text-slate-900 dark:text-slate-50">
                {m.name}
              </span>
              <span className="block text-[11px] text-slate-500 dark:text-slate-400">{m.detail}</span>
            </span>
            <Signal strength={m.strength} />
          </button>
        </li>
      ))}
    </ul>
  )
}

export function Signal({ strength }: { strength: number }) {
  const voice = useVoice
  void voice
  return (
    <span className="flex items-end gap-[3px]" aria-label={`信号 ${strength} 格`}>
      {[1, 2, 3, 4].map((i) => (
        <span
          key={i}
          className={cn(
            'w-[3px] rounded-full',
            i <= strength ? 'bg-emerald-500' : 'bg-slate-200 dark:bg-slate-700',
          )}
          style={{ height: 4 + i * 3 }}
        />
      ))}
    </span>
  )
}
