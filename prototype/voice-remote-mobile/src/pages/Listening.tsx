import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { PhoneScreen } from '../components/PhoneScreen'
import { StatusBar } from '../components/StatusBar'
import { Waveform } from '../components/Waveform'

/** M-06 收音中：真实计时 + 实时电平 + 呼吸光环 */
export default function Listening() {
  const [sec, setSec] = useState(7)
  const { macName, backend, permissions } = useVoice()
  const navigate = useNavigate()
  const micOk = permissions.microphone === 'granted'

  useEffect(() => {
    const id = window.setInterval(() => setSec((s) => Math.min(60, s + 1)), 1000)
    return () => clearInterval(id)
  }, [])

  const timer = `0:${String(sec).padStart(2, '0')}`
  const warn = sec >= 50

  return (
    <PhoneScreen code="M-06" title="收音中">
      <StatusBar state="listening" macName={macName} backend={backend} timer={timer} warnTimer={warn} />

      <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-5">
        <div className="w-full rounded-2xl border border-rose-200 bg-rose-50/70 p-4">
          <div className="flex items-center justify-between text-xs font-semibold text-rose-700">
            <span>正在收音</span>
            <span className={cn('tabular-nums', warn ? 'text-amber-700' : 'text-rose-700')}>
              {timer} / 1:00
            </span>
          </div>
          <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-rose-200/70">
            <div
              className={cn('h-full rounded-full transition-all duration-300', warn ? 'bg-amber-500' : 'bg-rose-500')}
              style={{ width: `${(sec / 60) * 100}%` }}
            />
          </div>
          {warn && (
            <p className="mt-1.5 text-[11px] font-medium text-amber-800">快到最后了，马上自动结束</p>
          )}
        </div>

        <div className="mt-6 w-full rounded-2xl border border-slate-200 bg-white p-4">
          <Waveform active={micOk} intensity={1.1} variant={micOk ? 'accent' : 'muted'} height={96} />
          <p className="mt-1 text-center text-[11px] text-slate-500">
            {micOk ? '实时电平 · 静音时降到最低但不归零' : '麦克风未授权，收不到声音'}
          </p>
        </div>

        <p className="mt-6 rounded-full bg-slate-900 px-3 py-1.5 text-[11px] font-medium text-white">
          上滑取消 · 松手立刻识别
        </p>
      </div>

      <div className="flex shrink-0 flex-col items-center pb-10">
        <div className="relative grid place-items-center" style={{ height: 152 }}>
          <span className="breath-ring absolute h-[176px] w-[176px] rounded-full bg-rose-500/20" />
          <span className="breath-ring-slow absolute h-[216px] w-[216px] rounded-full bg-rose-500/10" />
          <button
            type="button"
            onClick={() => navigate('/m07')}
            aria-label="松手结束收音"
            className="relative z-10 grid h-[120px] w-[120px] place-items-center rounded-full bg-gradient-to-b from-rose-500 to-rose-600 text-white shadow-[0_22px_48px_-16px_rgba(244,63,94,0.95)] transition-transform duration-150 ease-out active:scale-[0.97]"
          >
            <span className="pointer-events-none absolute inset-[6px] rounded-full ring-1 ring-white/30" />
            <svg width="34" height="34" viewBox="0 0 24 24" fill="none" aria-hidden>
              <rect x="8.5" y="8.5" width="7" height="7" rx="1.6" fill="currentColor" />
            </svg>
          </button>
        </div>
        <p className="mt-2 text-sm font-semibold text-slate-800">松手结束</p>
      </div>
    </PhoneScreen>
  )
}
