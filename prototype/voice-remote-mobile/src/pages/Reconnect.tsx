import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Check,
  CircleAlert,
  Loader2,
  MonitorSmartphone,
  Network,
  RefreshCw,
  ShieldCheck,
  WifiOff,
} from 'lucide-react'
import { cn } from '../lib/utils'
import { MAC_LIST, useVoice } from '../store/voice'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Button } from '../components/ui/button'

interface Step {
  key: string
  title: string
  desc: string
  fix?: string
  ok?: boolean
}

const STEPS: Step[] = [
  { key: 'same', title: '手机和 Mac 在同一个 Wi-Fi', desc: '名字一模一样才算同一网络' },
  { key: 'app', title: 'Mac 端 App 在运行', desc: '菜单栏图标不应是灰色的' },
  { key: 'perm', title: 'Mac 已允许「辅助功能」', desc: '不给权限，字就送不到光标处' },
  { key: 'fw', title: '防火墙没有拦截', desc: '系统设置 › 网络 › 防火墙', fix: '去 Mac 设置' },
]

export default function Reconnect() {
  const [phase, setPhase] = useState<'checking' | 'retrying' | 'done'>('checking')
  const [okCount, setOkCount] = useState(0)
  const { pair } = useVoice()
  const navigate = useNavigate()

  useEffect(() => {
    if (phase !== 'checking') return
    const id = window.setInterval(() => {
      setOkCount((n) => {
        if (n >= 3) {
          clearInterval(id)
          return n
        }
        return n + 1
      })
    }, 650)
    return () => clearInterval(id)
  }, [phase])

  useEffect(() => {
    if (phase !== 'retrying') return
    const id = window.setTimeout(() => setPhase('done'), 2200)
    return () => clearTimeout(id)
  }, [phase])

  return (
    <PhoneScreen code="M-12" title="重连 · 排查">
      <ScrollArea className="px-4 pt-5">
        <div className="flex items-center gap-3">
          <span
            className={cn(
              'grid h-12 w-12 place-items-center rounded-full',
              phase === 'done'
                ? 'bg-emerald-500 text-white'
                : 'bg-amber-100 text-amber-700 ring-1 ring-amber-200',
            )}
          >
            {phase === 'done' ? <Check className="h-6 w-6" /> : <WifiOff className="h-6 w-6" />}
          </span>
          <div>
            <h1 className="text-lg font-semibold text-slate-900">
              {phase === 'done' ? '已重新连上' : '连接中断了'}
            </h1>
            <p className="text-xs text-slate-500">
              {phase === 'done' ? 'Studio · 设计台在等你说话' : '先看这四项，通常一项就解决了'}
            </p>
          </div>
        </div>

        <ul className="mt-4 space-y-2">
          {STEPS.map((s, i) => {
            const done = i < okCount
            const active = i === okCount && phase === 'checking'
            return (
              <li
                key={s.key}
                className="flex items-start gap-3 rounded-2xl border border-slate-200 bg-white p-3.5"
              >
                <span
                  className={cn(
                    'mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full text-white',
                    done ? 'bg-emerald-500' : active ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-400',
                  )}
                >
                  {done ? (
                    <Check className="h-3.5 w-3.5" />
                  ) : active ? (
                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                  ) : i === 3 ? (
                    <CircleAlert className="h-3.5 w-3.5" />
                  ) : (
                    <span className="text-[10px] font-bold">{i + 1}</span>
                  )}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-sm font-medium text-slate-900">{s.title}</span>
                    {done && <span className="text-[10px] font-semibold text-emerald-700">正常</span>}
                  </div>
                  <p className="mt-0.5 text-[11px] leading-relaxed text-slate-500">{s.desc}</p>
                  {s.fix && (
                    <button
                      type="button"
                      className="mt-1.5 inline-flex min-h-[32px] items-center gap-1 rounded-lg bg-slate-100 px-2 text-[11px] font-medium text-slate-700 hover:bg-slate-200"
                    >
                      {s.fix}
                    </button>
                  )}
                </div>
              </li>
            )
          })}
        </ul>

        <div className="mt-4 rounded-2xl border border-slate-200 bg-white p-3.5">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-semibold text-slate-700">附近的 Mac</span>
            <span className="text-[11px] text-slate-400">{MAC_LIST.length} 台</span>
          </div>
          <div className="mt-2 space-y-1.5">
            {MAC_LIST.map((m) => (
              <button
                key={m.id}
                type="button"
                onClick={() => {
                  pair(m.name)
                  navigate('/m05')
                }}
                className="flex min-h-[48px] w-full items-center gap-2 rounded-xl border border-slate-100 bg-slate-50/60 px-3 text-left text-xs font-medium text-slate-800 hover:border-blue-200 hover:bg-white"
              >
                <MonitorSmartphone className="h-4 w-4 text-slate-500" />
                <span className="flex-1 truncate">{m.name}</span>
                <span className="text-[10px] text-blue-700">连接</span>
              </button>
            ))}
          </div>
        </div>

        <div className="mt-3 flex items-start gap-2 rounded-xl bg-slate-100/80 p-3 text-[11px] leading-relaxed text-slate-600">
          <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-slate-500" />
          如果四项都正常还连不上，在 Mac 上重启配套 App 后再试一次。
        </div>
        <div className="h-4" />
      </ScrollArea>

      <div className="shrink-0 space-y-2 px-4 pb-8 pt-2">
        <Button
          size="lg"
          className="w-full"
          disabled={phase === 'retrying'}
          onClick={() => {
            if (phase === 'done') {
              pair(MAC_LIST[0].name)
              navigate('/m05')
              return
            }
            setOkCount(0)
            setPhase('retrying')
          }}
        >
          {phase === 'retrying' ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" /> 正在重连…
            </>
          ) : phase === 'done' ? (
            '回到语音主屏'
          ) : (
            <>
              <RefreshCw className="h-4 w-4" /> 重新检查并连接
            </>
          )}
        </Button>
        <button
          type="button"
          onClick={() => navigate('/m04')}
          className="flex min-h-[48px] w-full items-center justify-center gap-1.5 text-xs font-medium text-slate-500 hover:text-slate-800"
        >
          <Network className="h-4 w-4" /> 改用扫码配对
        </button>
      </div>
    </PhoneScreen>
  )
}
