import { Link, useNavigate } from 'react-router-dom'
import {
  ArrowRight,
  Bluetooth,
  ChevronRight,
  CircleHelp,
  Ear,
  Languages,
  LogOut,
  Monitor,
  Network,
  Unplug,
  Vibrate,
  Volume2,
} from 'lucide-react'
import { useVoice } from '../store/voice'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Switch } from '../components/ui/switch'
import { Badge } from '../components/ui/badge'
import { Button } from '../components/ui/button'
import { cn } from '../lib/utils'

function Row({
  children,
  className,
}: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex min-h-[52px] items-center gap-3 px-4 py-2.5', className)}>
      {children}
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-4">
      <h2 className="mb-1.5 px-4 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
        {title}
      </h2>
      <div className="divide-y divide-slate-100 overflow-hidden rounded-2xl border border-slate-200 bg-white">
        {children}
      </div>
    </section>
  )
}

export default function Settings() {
  const { haptic, sound, autoWake, stream, toggle, backend, setBackend, macName, setConnected } =
    useVoice()
  const navigate = useNavigate()

  return (
    <PhoneScreen code="M-11" title="设置">
      <ScrollArea className="px-0 pb-6 pt-4">
        <div className="px-4">
          <div className="flex items-center gap-3 rounded-2xl border border-slate-200 bg-white p-4">
            <span className="grid h-12 w-12 place-items-center rounded-xl bg-slate-900 text-[10px] font-bold text-white">
              Mac
            </span>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold text-slate-900">{macName}</div>
              <div className="flex items-center gap-1.5 text-[11px] text-emerald-700">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" /> 演示已连接 · Wi-Fi
              </div>
            </div>
            <Link
              to="/m12"
              className="flex min-h-[40px] items-center gap-0.5 rounded-lg px-2 text-[11px] font-medium text-blue-700 hover:bg-blue-50"
            >
              管理 <ChevronRight className="h-3.5 w-3.5" />
            </Link>
          </div>
        </div>

        <div className="px-4">
          <Section title="识别通道">
            {(
              [
                { key: 'local' as const, name: '本地识别', desc: '在 Mac 上识别，音频不出局域网', icon: <Ear className="h-4 w-4" /> },
                { key: 'ime' as const, name: '输入法通道', desc: '已发送到输入法，上屏结果需确认', icon: <Languages className="h-4 w-4" /> },
              ]
            ).map((opt) => (
              <button
                key={opt.key}
                type="button"
                onClick={() => setBackend(opt.key)}
                className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-slate-50"
              >
                <span className="grid h-8 w-8 place-items-center rounded-lg bg-slate-100 text-slate-500">
                  {opt.icon}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-medium text-slate-900">{opt.name}</span>
                  <span className="block text-[11px] text-slate-500">{opt.desc}</span>
                </span>
                {backend === opt.key ? (
                  <Badge variant="success">使用中</Badge>
                ) : (
                  <span className="text-[11px] text-slate-400">切换</span>
                )}
              </button>
            ))}
          </Section>

          <Section title="反馈">
            <Row>
              <Vibrate className="h-4 w-4 text-slate-500" />
              <div className="flex-1">
                <div className="text-sm font-medium text-slate-900">触觉反馈</div>
                <div className="text-[11px] text-slate-500">按下 / 收音 / 上屏 三种不同震动</div>
              </div>
              <Switch checked={haptic} onChange={() => toggle('haptic')} label="触觉反馈" />
            </Row>
            <Row>
              <Volume2 className="h-4 w-4 text-slate-500" />
              <div className="flex-1">
                <div className="text-sm font-medium text-slate-900">提示音</div>
                <div className="text-[11px] text-slate-500">默认关闭，开会时更安静</div>
              </div>
              <Switch checked={sound} onChange={() => toggle('sound')} label="提示音" />
            </Row>
            <Row>
              <Monitor className="h-4 w-4 text-slate-500" />
              <div className="flex-1">
                <div className="text-sm font-medium text-slate-900">收音时屏幕常亮</div>
                <div className="text-[11px] text-slate-500">长句不会中途黑屏</div>
              </div>
              <Switch checked={autoWake} onChange={() => toggle('autoWake')} label="收音时屏幕常亮" />
            </Row>
            <Row>
              <ArrowRight className="h-4 w-4 text-slate-500" />
              <div className="flex-1">
                <div className="text-sm font-medium text-slate-900">流式预览</div>
                <div className="text-[11px] text-slate-500">说完一半就显示字，V1 默认关</div>
              </div>
              <Switch checked={stream} onChange={() => toggle('stream')} label="流式预览" />
            </Row>
          </Section>

          <Section title="连接">
            <Link to="/m03" className="flex w-full items-center gap-3 px-4 py-3 hover:bg-slate-50">
              <Network className="h-4 w-4 text-slate-500" />
              <span className="flex-1 text-sm font-medium text-slate-900">重新搜索 Mac</span>
              <ChevronRight className="h-4 w-4 text-slate-300" />
            </Link>
            <Link to="/m04" className="flex w-full items-center gap-3 px-4 py-3 hover:bg-slate-50">
              <Bluetooth className="h-4 w-4 text-slate-500" />
              <span className="flex-1 text-sm font-medium text-slate-900">扫码配对另一台 Mac</span>
              <ChevronRight className="h-4 w-4 text-slate-300" />
            </Link>
            <Link to="/m12" className="flex w-full items-center gap-3 px-4 py-3 hover:bg-slate-50">
              <CircleHelp className="h-4 w-4 text-slate-500" />
              <span className="flex-1 text-sm font-medium text-slate-900">连不上？一步步排查</span>
              <ChevronRight className="h-4 w-4 text-slate-300" />
            </Link>
          </Section>

          <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50/60 p-4">
            <p className="text-xs text-rose-800">断开后可以随时在「搜索 Mac」里重连。</p>
            <Button
              variant="outline"
              className="mt-2 h-11 w-full border-rose-200 bg-white text-rose-700 hover:bg-rose-50"
              onClick={() => {
                setConnected(false)
                navigate('/m13')
              }}
            >
              <Unplug className="h-4 w-4" />
              断开这台 Mac
            </Button>
          </div>

          <div className="mt-4 flex items-center justify-between px-1 text-[11px] text-slate-400">
            <span>语音遥控 1.0.0 · 原型</span>
            <span className="inline-flex items-center gap-1">
              <LogOut className="h-3 w-3" /> 退出设置
            </span>
          </div>
        </div>
      </ScrollArea>
    </PhoneScreen>
  )
}
