import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Loader2 } from 'lucide-react'
import { useVoice } from '../store/voice'
import { PhoneScreen } from '../components/PhoneScreen'
import { StatusBar } from '../components/StatusBar'
import { Waveform } from '../components/Waveform'

/** M-07 识别中：转圈禁用，3 秒超时自动转 M-09 */
export default function Recognizing() {
  const { macName, backend, setErrorMode } = useVoice()
  const navigate = useNavigate()
  const [step, setStep] = useState(0)

  useEffect(() => {
    const a = window.setTimeout(() => setStep(1), 1000)
    const b = window.setTimeout(() => setStep(2), 2000)
    const c = window.setTimeout(() => {
      setErrorMode('timeout')
      navigate('/m09')
    }, 3000)
    return () => {
      clearTimeout(a)
      clearTimeout(b)
      clearTimeout(c)
    }
  }, [navigate, setErrorMode])

  return (
    <PhoneScreen code="M-07" title="识别中">
      <StatusBar state="recognizing" macName={macName} backend={backend} />

      <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-6">
        <div className="flex h-16 items-center gap-1.5">
          {[0, 1, 2, 3, 4].map((i) => (
            <span
              key={i}
              className="w-2 rounded-full bg-blue-500 pulse-dot"
              style={{ animationDelay: `${i * 0.12}s`, height: 10 }}
            />
          ))}
        </div>
        <h1 className="mt-6 text-lg font-semibold text-slate-900">正在识别…</h1>
        <p className="mt-1 text-sm text-slate-500">在 Mac 上处理，不会上传音频</p>

        <div className="mt-8 w-full space-y-2 rounded-2xl border border-slate-200 bg-white p-4">
          {['正在读这段音频', '整理成一句话', '送到 Mac 光标处'].map((t, i) => (
            <div key={t} className="flex items-center gap-2.5 text-xs">
              {i < step ? (
                <span className="grid h-5 w-5 place-items-center rounded-full bg-emerald-500 text-white">
                  <svg width="11" height="11" viewBox="0 0 12 12" fill="none" aria-hidden>
                    <path d="M2.5 6.2l2.3 2.3 4.7-5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </span>
              ) : i === step ? (
                <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
              ) : (
                <span className="h-5 w-5 rounded-full border border-slate-200" />
              )}
              <span className={i <= step ? 'font-medium text-slate-800' : 'text-slate-400'}>{t}</span>
            </div>
          ))}
        </div>

        <Waveform active height={64} className="mt-6 w-full opacity-60" />
        <p className="mt-2 text-[11px] text-slate-400">超过 3 秒没结果会自动提示重试</p>
      </div>

      <div className="flex shrink-0 flex-col items-center pb-12">
        <div className="grid h-[112px] w-[112px] place-items-center rounded-full bg-slate-200 text-slate-500">
          <Loader2 className="h-10 w-10 animate-spin" aria-hidden />
        </div>
        <p className="mt-4 text-sm font-medium text-slate-500">松手了，等结果</p>
        <button
          type="button"
          onClick={() => navigate('/m05')}
          className="mt-2 min-h-[48px] px-4 text-xs font-medium text-slate-400 hover:text-slate-700"
        >
          取消这次输入
        </button>
      </div>
    </PhoneScreen>
  )
}
