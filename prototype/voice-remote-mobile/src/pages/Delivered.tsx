import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Check, Copy, MonitorUp } from 'lucide-react'
import { useVoice } from '../store/voice'
import { PhoneScreen } from '../components/PhoneScreen'
import { StatusBar } from '../components/StatusBar'
import { Button } from '../components/ui/button'

/** M-08 上屏成功：绿竖条 2 s 后淡出，1.5 s 回转 M-05（这里给足阅读时间） */
export default function Delivered() {
  const { last, macName, backend } = useVoice()
  const navigate = useNavigate()
  const [copied, setCopied] = useState(false)
  const [barFaded, setBarFaded] = useState(false)

  useEffect(() => {
    const t = window.setTimeout(() => setBarFaded(true), 2000)
    return () => clearTimeout(t)
  }, [])

  const copy = async () => {
    try {
      await navigator.clipboard?.writeText(last.text)
    } catch {
      /* 原型环境无剪贴板权限时静默 */
    }
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <PhoneScreen code="M-08" title="上屏成功">
      <StatusBar state="success" macName={macName} backend={backend} />

      <div className="min-h-0 flex-1 overflow-y-auto no-scrollbar px-4 pt-6">
        <div className="flex items-center gap-3">
          <span className="grid h-12 w-12 place-items-center rounded-full bg-emerald-500 text-white shadow-[0_12px_26px_-14px_rgba(16,185,129,0.9)]">
            <Check className="h-7 w-7" />
          </span>
          <div>
            <h1 className="text-lg font-semibold text-slate-900">已出现在 Mac 上</h1>
            <p className="text-xs text-slate-500">送到了「备忘录 · 项目周报」光标处</p>
          </div>
        </div>

        <div className="relative mt-5 overflow-hidden rounded-2xl border border-slate-200 bg-white p-4 pl-5 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
          <span
            aria-hidden
            className="absolute inset-y-3 left-0 w-1.5 rounded-full bg-emerald-500 transition-opacity duration-700"
            style={{ opacity: barFaded ? 0 : 1 }}
          />
          <p className="text-[15px] leading-relaxed text-slate-900">{last.text}</p>
          <div className="mt-3 flex items-center justify-between border-t border-slate-100 pt-2.5 text-[11px]">
            <span className="text-slate-500">{last.text.length} 字 · 示例用时 0.3 秒 · Mac 端识别</span>
            <button
              type="button"
              onClick={copy}
              className="inline-flex min-h-[40px] items-center gap-1 rounded-lg px-2 font-medium text-blue-700 hover:bg-blue-50"
            >
              {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
              {copied ? '已复制' : '复制'}
            </button>
          </div>
        </div>

        <div className="mt-3 flex items-center gap-2 rounded-xl bg-emerald-50 p-3 text-[11px] text-emerald-800 ring-1 ring-emerald-200">
          <MonitorUp className="h-4 w-4 shrink-0" />
          Mac 上可以直接按 ⌘Z 撤回这段文字
        </div>

        <p className="mt-4 text-center text-[11px] text-slate-400">
          1.5 秒后回到主屏，文本卡会留着给你复制
        </p>
      </div>

      <div className="shrink-0 px-4 pb-8 pt-2">
        <Button size="lg" className="w-full" onClick={() => navigate('/m05')}>
          回到主屏
        </Button>
      </div>
    </PhoneScreen>
  )
}
