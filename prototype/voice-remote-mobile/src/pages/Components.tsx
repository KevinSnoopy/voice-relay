import { useState } from 'react'
import { Check, Mic, RotateCw, X, Wifi, WifiOff, MicOff, Loader2, CornerDownLeft } from 'lucide-react'
import { cn } from '../lib/utils'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Waveform } from '../components/Waveform'
import { StatusBar } from '../components/StatusBar'
import { Button } from '../components/ui/button'
import { Badge } from '../components/ui/badge'

export default function Components() {
  const [holdActive, setHoldActive] = useState(false)
  const [waveActive, setWaveActive] = useState(true)

  return (
    <PhoneScreen code="C-01" title="组件页" bare>
      <div className="flex h-12 shrink-0 items-center justify-between border-b border-slate-200/70 bg-white/85 px-4 backdrop-blur">
        <div className="leading-tight">
          <div className="text-sm font-semibold text-slate-900">语音遥控 · 组件库</div>
          <div className="text-[11px] text-slate-400">C-01 · 主按钮 4 态 / 状态条 7 态 / 波形 / 卡片 / 列表项</div>
        </div>
        <Badge variant="default">14 个画板</Badge>
      </div>

      <ScrollArea className="px-4 pb-8 pt-4">
        <section>
          <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">主按钮 · 4 态</h2>
          <div className="mt-2 grid grid-cols-4 gap-2 rounded-2xl border border-slate-200 bg-white p-3">
            {[
              { label: '空闲', cls: 'from-blue-500 to-blue-600', node: <Mic className="h-6 w-6" /> },
              { label: '按下', cls: 'from-blue-600 to-blue-700', node: <Mic className="h-6 w-6" />, ring: true },
              { label: '取消区', cls: 'from-rose-500 to-rose-600', node: <X className="h-6 w-6" /> },
              { label: '识别中', cls: 'from-slate-300 to-slate-400', node: <RotateCw className="h-6 w-6 animate-spin" /> },
            ].map((s) => (
              <div key={s.label} className="flex flex-col items-center gap-2">
                <span
                  className={cn(
                    'grid h-16 w-16 place-items-center rounded-full bg-gradient-to-b text-white transition-all duration-150',
                    s.cls,
                    s.ring && 'ring-4 ring-blue-200',
                  )}
                >
                  {s.node}
                </span>
                <span className="text-[11px] text-slate-600">{s.label}</span>
              </div>
            ))}
          </div>
          <div className="mt-2 grid grid-cols-4 gap-2">
            <Button className="col-span-2" onClick={() => setHoldActive((v) => !v)}>
              {holdActive ? '已按下 120ms' : '按下主按钮'}
            </Button>
            <Button variant="outline" className="border-slate-200">
              次要
            </Button>
            <Button variant="ghost">轻量</Button>
          </div>
        </section>

        <section className="mt-5">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">状态条 · 7 态</h2>
          <div className="mt-2 divide-y divide-slate-100 overflow-hidden rounded-2xl border border-slate-200 bg-white">
            {(['connected', 'listening', 'recognizing', 'success', 'submitted', 'failed', 'disconnected'] as const).map(
              (s) => (
                <StatusBar
                  key={s}
                  state={s}
                  macName="Studio · 设计台"
                  backend="local"
                  timer={s === 'listening' ? '0:07' : undefined}
                  className="h-11"
                />
              ),
            )}
          </div>
        </section>

        <section className="mt-5">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">波形</h2>
            <button
              type="button"
              onClick={() => setWaveActive((v) => !v)}
              className="rounded-lg px-2 py-1 text-[11px] font-medium text-blue-700 hover:bg-blue-50"
            >
              {waveActive ? '切到静止' : '开始收音'}
            </button>
          </div>
          <div className="mt-2 space-y-2">
            <div className="rounded-2xl border border-slate-200 bg-white p-2">
              <Waveform active={waveActive} variant="accent" height={72} />
              <p className="text-center text-[11px] text-slate-500">收音中 · 每帧插值</p>
            </div>
            <div className="rounded-2xl border border-slate-200 bg-white p-2">
              <Waveform active={false} height={48} />
              <p className="text-center text-[11px] text-slate-500">空闲 · 静止细线</p>
            </div>
          </div>
        </section>

        <section className="mt-5">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">卡片</h2>
          <div className="mt-2 space-y-2">
            <div className="relative overflow-hidden rounded-2xl border border-slate-200 bg-white p-3.5 pl-4">
              <span className="absolute inset-y-3 left-0 w-1.5 rounded-full bg-emerald-500" />
              <div className="flex items-center justify-between text-[11px]">
                <span className="font-medium text-slate-500">上屏成功</span>
                <Badge variant="success">
                  <Check className="h-3 w-3" /> 已送达
                </Badge>
              </div>
              <p className="mt-1.5 text-sm leading-relaxed text-slate-900">
                已经出现在备忘录第 3 段开头，直接接着写就行。
              </p>
            </div>
            <div className="rounded-2xl border border-amber-200 bg-amber-50 p-3.5">
              <div className="flex items-center gap-2 text-[11px] font-medium text-amber-900">
                <MicOff className="h-4 w-4" /> 上屏失败
              </div>
              <p className="mt-1 text-[11px] text-amber-800">当前没有可输入的位置 · 点一下输入框再试</p>
            </div>
            <div className="grid place-items-center rounded-2xl border border-dashed border-slate-300 bg-slate-50/60 py-6 text-center">
              <Loader2 className="h-5 w-5 text-slate-300" />
              <p className="mt-1 text-[11px] text-slate-500">空态：还没有上过屏</p>
            </div>
          </div>
        </section>

        <section className="mt-5">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">列表项</h2>
          <div className="mt-2 divide-y divide-slate-100 overflow-hidden rounded-2xl border border-slate-200 bg-white">
            {[
              { name: 'Studio · 设计台', detail: '在线 · 信号很好', icon: <Wifi className="h-4 w-4" />, tone: 'text-emerald-600' },
              { name: '周屿的 MacBook Air', detail: '配对过 · 信号良好', icon: <Wifi className="h-4 w-4" />, tone: 'text-emerald-600' },
              { name: '会议室 Mac mini', detail: '离线 · 上次 2 天前', icon: <WifiOff className="h-4 w-4" />, tone: 'text-slate-400' },
            ].map((r) => (
              <div key={r.name} className="flex min-h-[56px] items-center gap-3 px-3.5">
                <span className={cn('grid h-8 w-8 place-items-center rounded-lg bg-slate-100', r.tone)}>
                  {r.icon}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-medium text-slate-900">{r.name}</div>
                  <div className="text-[11px] text-slate-500">{r.detail}</div>
                </div>
                <CornerDownLeft className="h-4 w-4 text-slate-300" />
              </div>
            ))}
          </div>
        </section>

        <section className="mt-5">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-500">徽标</h2>
          <div className="mt-2 flex flex-wrap gap-2 rounded-2xl border border-slate-200 bg-white p-3">
            <Badge>默认</Badge>
            <Badge variant="success">已连接</Badge>
            <Badge variant="warning">待授权</Badge>
            <Badge variant="danger">已拒绝</Badge>
            <Badge variant="muted">Mac 端</Badge>
            <Badge variant="outline">轻量</Badge>
          </div>
        </section>
      </ScrollArea>
    </PhoneScreen>
  )
}
