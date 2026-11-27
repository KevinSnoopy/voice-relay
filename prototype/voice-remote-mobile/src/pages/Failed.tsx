import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Check, Copy, Focus, RotateCw, TriangleAlert, WifiOff, X } from 'lucide-react'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { ERROR_REASONS } from '../data/apps'
import { PhoneScreen } from '../components/PhoneScreen'
import { StatusBar } from '../components/StatusBar'
import { Button } from '../components/ui/button'

const ICON_MAP: Record<string, React.ReactNode> = {
  focus: <Focus className="h-4 w-4" />,
  clock: <TriangleAlert className="h-4 w-4" />,
  wifi: <WifiOff className="h-4 w-4" />,
  lock: <TriangleAlert className="h-4 w-4" />,
}

export default function Failed() {
  const { last, macName, backend, saveLast, errorMode, setErrorMode } = useVoice()
  const navigate = useNavigate()
  const [copied, setCopied] = useState(false)

  const reason =
    ERROR_REASONS.find((r) => r.code === (errorMode ?? 'no_focus')) ?? ERROR_REASONS[0]

  const copy = async () => {
    try {
      await navigator.clipboard?.writeText(last.text)
    } catch {
      /* 原型环境无剪贴板权限时静默 */
    }
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1600)
  }

  const ignore = () => {
    setErrorMode(null)
    saveLast(last.text, 'failed', reason.text, last.target)
    navigate('/m05')
  }

  return (
    <PhoneScreen code="M-09" title="上屏失败">
      <StatusBar state="failed" macName={macName} backend={backend} />

      <div className="min-h-0 flex-1 overflow-y-auto no-scrollbar px-4 pt-5">
        <div className="flex items-center gap-3">
          <span className="grid h-12 w-12 place-items-center rounded-full bg-amber-100 text-amber-700 ring-1 ring-amber-200">
            <TriangleAlert className="h-7 w-7" />
          </span>
          <div>
            <h1 className="text-lg font-semibold text-slate-900">字识别出来了，没送进去</h1>
            <p className="text-xs text-slate-500">文字还在，不会丢</p>
          </div>
        </div>

        <div className="mt-4 flex items-center gap-2 rounded-xl bg-amber-50 p-3 text-xs text-amber-900 ring-1 ring-amber-200">
          <span className="text-amber-700">{ICON_MAP[reason.icon]}</span>
          <p className="flex-1 font-medium">{reason.text}</p>
          <span className="shrink-0 rounded-full bg-white px-2 py-0.5 text-[10px] font-semibold text-amber-800">
            {reason.hint}
          </span>
        </div>

        <div className="mt-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
          <div className="flex items-center justify-between text-[11px]">
            <span className="font-medium text-slate-500">识别结果</span>
            <span className="text-slate-400">{last.text.length} 字</span>
          </div>
          <p className="mt-2 text-[15px] leading-relaxed text-slate-900">{last.text}</p>
        </div>

        <div className="mt-3 space-y-2">
          {ERROR_REASONS.filter((r) => r.code !== (errorMode ?? 'no_focus')).slice(0, 2).map((r) => (
            <button
              key={r.code}
              type="button"
              onClick={() => setErrorMode(r.code)}
              className={cn(
                'flex w-full min-h-[44px] items-center gap-2 rounded-xl border px-3 text-left text-[11px] transition-colors',
                r.code === reason.code
                  ? 'border-amber-300 bg-amber-50 text-amber-900'
                  : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50',
              )}
            >
              {ICON_MAP[r.icon]}
              演示其他原因：{r.text}
            </button>
          ))}
        </div>
      </div>

      <div className="shrink-0 space-y-2 border-t border-slate-200/70 px-4 pb-8 pt-3">
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="lg"
            className="flex-1 border-slate-200"
            onClick={copy}
          >
            {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
            {copied ? '已复制' : '复制文本'}
          </Button>
          <Button
            size="lg"
            className="flex-1"
            onClick={() => {
              saveLast(last.text, 'success', undefined, '备忘录 · 项目周报')
              setErrorMode(null)
              navigate('/m07')
            }}
          >
            <RotateCw className="h-4 w-4" />
            重试
          </Button>
        </div>
        <button
          type="button"
          onClick={ignore}
          className="flex min-h-[48px] w-full items-center justify-center gap-1.5 rounded-xl text-xs font-medium text-slate-500 hover:bg-slate-100"
        >
          <X className="h-4 w-4" />
          忽略，回到主屏
        </button>
      </div>
    </PhoneScreen>
  )
}
