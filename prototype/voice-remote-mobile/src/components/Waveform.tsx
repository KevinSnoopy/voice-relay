import { cn } from '../lib/utils'
import { useLevels } from '../hooks/useLevels'

interface WaveformProps {
  active: boolean
  intensity?: number
  variant?: 'primary' | 'accent' | 'muted'
  className?: string
  height?: number
}

const COLORS = {
  primary: 'bg-blue-600',
  accent: 'bg-rose-500',
  muted: 'bg-slate-300',
}

/** 签名视觉：五根竖条电平波形，空闲时为静止细线 */
export function Waveform({
  active,
  intensity = 1,
  variant = 'primary',
  className,
  height = 96,
}: WaveformProps) {
  const levels = useLevels({ active, intensity })
  void levels
  const barWidth = 10
  const resting = Math.max(2, Math.round(height * 0.02))
  const idle = [0.22, 0.4, 0.62, 0.4, 0.22]
  const shown = active ? levels : idle

  return (
    <div
      role="img"
      aria-label={active ? '实时电平波形，正在收音' : '电平波形，当前静止'}
      className={cn('flex items-center justify-center gap-[10px]', className)}
      style={{ height }}
    >
      {shown.map((v, i) => {
        const h = active ? Math.max(6, v * height * 0.92) : resting
        return (
          <span
            key={i}
            className={cn(
              'rounded-full transition-colors duration-200',
              active ? COLORS[variant] : 'bg-slate-300',
            )}
            style={{
              width: barWidth,
              height: h,
              opacity: active ? 0.55 + v * 0.45 : 1,
            }}
          />
        )
      })}
    </div>
  )
}
