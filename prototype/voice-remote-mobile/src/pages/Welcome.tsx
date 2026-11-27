import { Link, useNavigate } from 'react-router-dom'
import { ArrowRight, Laptop2, Mic, Radio, Smartphone } from 'lucide-react'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Waveform } from '../components/Waveform'
import { Button } from '../components/ui/button'
import { Badge } from '../components/ui/badge'

export default function Welcome() {
  const navigate = useNavigate()
  return (
    <PhoneScreen code="M-01" title="首次启动 · 欢迎" homeIndicator={false}>
      <ScrollArea className="flex flex-col justify-center px-6">
        <div className="mx-auto w-full max-w-[360px] py-8">
          <div className="relative flex flex-col items-center">
            <div className="relative grid h-24 w-24 place-items-center rounded-[28px] bg-gradient-to-br from-blue-500 to-blue-700 text-white shadow-[0_24px_48px_-18px_rgba(37,99,235,0.9)]">
              <Mic className="h-10 w-10" aria-hidden />
              <span className="absolute -right-2 -top-2 grid h-8 w-8 place-items-center rounded-full bg-white text-blue-600 shadow ring-1 ring-blue-100">
                <Laptop2 className="h-4 w-4" />
              </span>
            </div>
            <div className="mt-6 flex items-center gap-1.5 rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-medium text-slate-600">
              <Radio className="h-3 w-3 text-emerald-600" /> 遥控器 + 麦克风
            </div>
          </div>

          <h1 className="mt-6 text-center text-[26px] font-bold leading-[1.3] tracking-tight text-slate-900 text-balance">
            按住说话，<br />字出现在 Mac 上
          </h1>
          <p className="mx-auto mt-3 max-w-[280px] text-center text-sm leading-relaxed text-slate-500">
            手机只负责说，Mac 负责写。先在 Mac 上装一个配套 App，两端连上就能用。
          </p>

          <div className="mt-7 rounded-2xl border border-slate-200 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-slate-700">连上后的样子</span>
              <Badge variant="success">目标 ≤ 0.3 秒</Badge>
            </div>
            <div className="mt-2 flex items-center gap-3">
              <Smartphone className="h-4 w-4 shrink-0 text-slate-400" />
              <Waveform active height={44} className="flex-1" />
              <Laptop2 className="h-4 w-4 shrink-0 text-slate-400" />
            </div>
            <p className="mt-1 text-[11px] text-slate-500">录音不进云，文字在 Mac 上识别后直接送到光标。</p>
          </div>

          <Button size="lg" className="mt-6 w-full" onClick={() => navigate('/m02')}>
            开始设置
            <ArrowRight className="h-4 w-4" />
          </Button>
          <div className="mt-3 pb-6 text-center">
            <Link
              to="/m03"
              className="inline-flex min-h-[48px] items-center text-sm font-medium text-blue-700 underline-offset-4 hover:underline"
            >
              我已经装好了 Mac 端
            </Link>
          </div>
        </div>
      </ScrollArea>
    </PhoneScreen>
  )
}
