import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Mic, RotateCw, X } from 'lucide-react'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { VOICE_SAMPLES } from '../data/apps'

void VOICE_SAMPLES

type Phase = 'idle' | 'listening' | 'canceling' | 'recognizing'

interface HoldButtonProps {
  onRecognized: (text: string) => void
  onTimeout: () => void
  disabled?: boolean
  /** 用于原型演示：点击一下也能自动走完整流程 */
  className?: string
}

const CANCEL_DISTANCE = 64
const MAX_SECONDS = 60

/** 主按钮 4 态：空闲 / 收音 / 取消区 / 识别中 */
export function HoldButton({ onRecognized, onTimeout, disabled, className }: HoldButtonProps) {
  const [phase, setPhase] = useState<Phase>('idle')
  const [elapsed, setElapsed] = useState(0)
  const startRef = useRef(0)
  const startY = useRef(0)
  const longPressTimer = useRef<number | null>(null)
  const timers = useRef<number[]>([])
  const navigate = useNavigate()
  const haptic = useVoice((s) => s.haptic)
  void haptic

  useEffect(() => () => {
    timers.current.forEach((t) => clearTimeout(t))
  }, [])

  const clearTimers = () => {
    timers.current.forEach((t) => clearTimeout(t))
    timers.current = []
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }
  }

  const beginListening = () => {
    startRef.current = performance.now()
    setElapsed(0)
    setPhase('listening')
  }

  const finish = (cancelled: boolean) => {
    if (phase !== 'listening' && phase !== 'canceling') return
    if (cancelled) {
      setPhase('idle')
      return
    }
    setPhase('recognizing')
    timers.current.push(
      window.setTimeout(() => {
        // 3 秒超时 → 转到失败画板
        onTimeout()
        setPhase('idle')
        navigate('/m09')
      }, 3000),
    )
    timers.current.push(
      window.setTimeout(
        () => {
          onRecognized('把第三段的标题改短一点，下面两行跟上节奏。')
          setPhase('idle')
        },
        1300,
      ),
    )
  }

  const onPointerDown = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (disabled || phase === 'recognizing') return
    ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
    startY.current = e.clientY
    beginListening()
    // 短按（<220 ms）视为演示自动走完整个流程
    longPressTimer.current = window.setTimeout(() => {
      longPressTimer.current = null
    }, 220)
  }

  const onPointerMove = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (phase !== 'listening' && phase !== 'canceling') return
    const dy = startY.current - e.clientY
    setPhase(dy > CANCEL_DISTANCE ? 'canceling' : 'listening')
  }

  const onPointerUp = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (phase !== 'listening' && phase !== 'canceling') return
    const dy = startY.current - e.clientY
    const quickTap = performance.now() - startRef.current < 220
    const cancelled = phase === 'canceling' || dy > CANCEL_DISTANCE
    if (quickTap && !cancelled) {
      clearTimers()
      beginListening()
      window.setTimeout(() => finish(false), 900)
      return
    }
    finish(cancelled)
  }

  useEffect(() => {
    if (phase !== 'listening' && phase !== 'canceling') return
    const id = window.setInterval(() => {
      const sec = Math.min(MAX_SECONDS, Math.floor((performance.now() - startRef.current) / 1000))
      setElapsed(sec)
      if (sec >= MAX_SECONDS) finish(false)
    }, 200)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase])

  const isActive = phase === 'listening' || phase === 'canceling'
  const isCancel = phase === 'canceling'
  const size = isActive ? 120 : 112

  return (
    <div className={cn('flex flex-col items-center', className)}>
      <div className="relative flex items-center justify-center" style={{ height: 176 }}>
        {isActive && (
          <>
            <span className="absolute rounded-full bg-blue-500/20 breath-ring" style={{ width: size + 56, height: size + 56 }} />
            <span className="absolute rounded-full bg-blue-500/10 breath-ring-slow" style={{ width: size + 96, height: size + 96 }} />
          </>
        )}
        {isCancel && <span className="absolute rounded-full bg-rose-500/15" style={{ width: size + 48, height: size + 48 }} />}
        <button
          type="button"
          aria-label={
            phase === 'recognizing'
              ? '正在识别，请稍候'
              : isCancel
                ? '松手取消收音'
                : '按住说话'
          }
          aria-pressed={isActive}
          disabled={disabled || phase === 'recognizing'}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={() => finish(true)}
          className={cn(
            'relative z-10 grid place-items-center rounded-full text-white transition-[transform,background-color,box-shadow] duration-150 ease-out active:scale-[0.97] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-blue-300 disabled:cursor-not-allowed',
            isCancel
              ? 'bg-rose-500 shadow-[0_20px_45px_-15px_rgba(244,63,94,0.85)]'
              : 'bg-gradient-to-b from-blue-500 to-blue-600 shadow-[0_22px_48px_-16px_rgba(37,99,235,0.95)]',
            disabled && !isActive && 'from-slate-300 to-slate-300 shadow-none',
          )}
          style={{ width: size, height: size, transitionDuration: '150ms' }}
        >
          <span className="pointer-events-none absolute inset-[6px] rounded-full ring-1 ring-white/25" />
          {phase === 'recognizing' ? (
            <RotateCw className="h-9 w-9 animate-spin" aria-hidden />
          ) : isCancel ? (
            <X className="h-10 w-10" aria-hidden />
          ) : (
            <Mic className="h-10 w-10" aria-hidden />
          )}
        </button>
      </div>
      <p className="mt-1 text-sm font-medium text-slate-700" aria-live="polite">
        {phase === 'recognizing'
          ? '正在识别…'
          : isCancel
            ? '松手取消'
            : isActive
              ? '上滑取消 · 松手结束'
              : elapsed > 0
                ? '松手结束'
                : '按住说话 · 松手结束'}
      </p>
    </div>
  )
}
