import { Link } from 'react-router-dom'
import {
  ArrowRight,
  Bell,
  Bluetooth,
  CheckCircle2,
  CircleSlash2,
  Download,
  LayoutGrid,
  Link2Off,
  Loader2,
  Lock,
  Mic,
  Play,
  QrCode,
  Radio,
  RefreshCw,
  Search,
  Settings2,
  SquarePen,
} from 'lucide-react'
import { cn } from '../lib/utils'
import { ScrollArea } from '../components/PhoneScreen'
import { Waveform } from '../components/Waveform'
import { Badge } from '../components/ui/badge'
import { Button } from '../components/ui/button'
import { useVoice } from '../store/voice'

interface Board {
  code: string
  title: string
  desc: string
  path: string
  icon: React.ReactNode
  accent: string
  flow: string
}

const GROUPS: { title: string; hint: string; boards: Board[] }[] = [
  {
    title: '首次引导',
    hint: '只走一次，权限 → 找到 Mac → 配对上',
    boards: [
      { code: 'M-01', title: '欢迎', desc: '标题 + 开始设置 + 已有 Mac 端', path: '/m01', icon: <Mic className="h-4 w-4" />, accent: 'bg-blue-50 text-blue-700 ring-blue-100', flow: '第 1 步' },
      { code: 'M-02', title: '权限', desc: '麦克风必需 · 三项卡片带勾选态', path: '/m02', icon: <Lock className="h-4 w-4" />, accent: 'bg-violet-50 text-violet-700 ring-violet-100', flow: '第 2 步' },
      { code: 'M-03', title: '搜索 Mac', desc: '雷达扫描 · 4 种状态可切换', path: '/m03', icon: <Search className="h-4 w-4" />, accent: 'bg-cyan-50 text-cyan-700 ring-cyan-100', flow: '第 3 步' },
      { code: 'M-04', title: '扫码配对', desc: '全屏取景框 + 改用自动发现', path: '/m04', icon: <QrCode className="h-4 w-4" />, accent: 'bg-slate-100 text-slate-700 ring-slate-200', flow: '备用' },
    ],
  },
  {
    title: '一次语音输入',
    hint: '按住 · 说话 · 松手，四块画板连着看',
    boards: [
      { code: 'M-05', title: '已连接', desc: '状态条 · 最近一条 · 主按钮 112', path: '/m05', icon: <Radio className="h-4 w-4" />, accent: 'bg-emerald-50 text-emerald-700 ring-emerald-100', flow: '主屏' },
      { code: 'M-06', title: '收音中', desc: '圆点变红 · 计时变黄 · 呼吸光环', path: '/m06', icon: <Mic className="h-4 w-4" />, accent: 'bg-rose-50 text-rose-700 ring-rose-100', flow: '按住' },
      { code: 'M-07', title: '识别中', desc: '转圈禁用 · 3 秒超时转失败', path: '/m07', icon: <Loader2 className="h-4 w-4" />, accent: 'bg-indigo-50 text-indigo-700 ring-indigo-100', flow: '松手' },
      { code: 'M-08', title: '上屏成功', desc: '绿竖条 2 秒淡出 · 文本可复制', path: '/m08', icon: <CheckCircle2 className="h-4 w-4" />, accent: 'bg-emerald-50 text-emerald-700 ring-emerald-100', flow: '成功' },
      { code: 'M-09', title: '上屏失败', desc: '文本不丢 · 复制 / 重试 / 忽略', path: '/m09', icon: <CircleSlash2 className="h-4 w-4" />, accent: 'bg-amber-50 text-amber-700 ring-amber-100', flow: '失败' },
    ],
  },
  {
    title: '遥控与连接',
    hint: '抽屉控制 Mac，出事有兜底',
    boards: [
      { code: 'M-11', title: '设置', desc: '识别通道 · 触觉 · 提示音', path: '/m11', icon: <Settings2 className="h-4 w-4" />, accent: 'bg-slate-100 text-slate-700 ring-slate-200', flow: '右上角' },
      { code: 'M-12', title: '重连', desc: '四项自检 + 附近 Mac 直连', path: '/m12', icon: <RefreshCw className="h-4 w-4" />, accent: 'bg-teal-50 text-teal-700 ring-teal-100', flow: '异常' },
      { code: 'M-13', title: '未连接', desc: '空态 + 上次文本 + 禁用主按钮', path: '/m13', icon: <Link2Off className="h-4 w-4" />, accent: 'bg-slate-100 text-slate-600 ring-slate-200', flow: '异常' },
    ],
  },
]

export default function Index() {
  const { backend, macName } = useVoice()
  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden bg-slate-50 text-slate-900">
      <header className="shrink-0 border-b border-slate-200/80 bg-white px-5 pb-4 pt-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="grid h-8 w-8 place-items-center rounded-xl bg-gradient-to-br from-blue-500 to-blue-700 text-white shadow-[0_8px_18px_-8px_rgba(37,99,235,0.9)]">
              <Mic className="h-4 w-4" />
            </span>
            <span className="text-sm font-semibold">语音遥控</span>
            <Badge variant="muted">原型 1.0</Badge>
            <Badge variant="warning">演示数据 · 非实时状态</Badge>
          </div>
          <div className="flex items-center gap-2 text-[11px] text-slate-500">
            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-1 text-emerald-700 ring-1 ring-emerald-100">
              <Bluetooth className="h-3 w-3" /> {macName}
            </span>
            <span className="hidden rounded-full bg-slate-100 px-2 py-1 sm:inline">
              {backend === 'local' ? '本地识别' : '输入法通道'}
            </span>
          </div>
        </div>
        <h1 className="mt-3 text-xl font-bold tracking-tight">按住说话，字出现在 Mac 上</h1>
        <p className="mt-1 max-w-2xl text-xs leading-relaxed text-slate-500">
          手机端 12 个画板 + 1 个组件页，逐块可点开验收。基准 390×844，锁定竖屏，支持深色模式与 1.3× 字号。
        </p>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <Button asChild size="sm">
            <Link to="/m01">
              <Play className="h-3.5 w-3.5" /> 从欢迎走一遍
            </Link>
          </Button>
          <Button asChild size="sm" variant="outline" className="border-slate-200">
            <Link to="/m05">
              <Mic className="h-3.5 w-3.5" /> 直接看主屏
            </Link>
          </Button>
          <Button asChild size="sm" variant="outline" className="border-slate-200">
            <Link to="/components">
              <LayoutGrid className="h-3.5 w-3.5" /> 组件页
            </Link>
          </Button>
          <span className="inline-flex items-center gap-1 rounded-full bg-white px-2.5 py-1 text-[11px] text-slate-500 ring-1 ring-slate-200">
            <Bell className="h-3 w-3" /> 触觉 + 电平 + 计时 全部可交互
          </span>
        </div>
      </header>

      <ScrollArea className="px-5 pb-8 pt-4">
        <div className="rounded-2xl border border-slate-200 bg-white p-3">
          <div className="flex items-center justify-between text-[11px] text-slate-500">
            <span className="font-semibold text-slate-700">主动线：按住 → 说话 → 松手 → 上屏</span>
            <span className="tabular-nums">示例延迟 0.3 秒</span>
          </div>
          <div className="mt-2 flex items-center gap-2">
            <Waveform active height={40} className="flex-1" />
            <div className="hidden items-center gap-1 text-[11px] font-medium text-slate-500 sm:flex">
              M-05 <ArrowRight className="h-3 w-3" /> M-06 <ArrowRight className="h-3 w-3" /> M-07 <ArrowRight className="h-3 w-3" /> M-08 / M-09
            </div>
          </div>
        </div>

        {GROUPS.map((g) => (
          <section key={g.title} className="mt-5">
            <div className="flex items-baseline justify-between">
              <h2 className="text-sm font-semibold text-slate-900">{g.title}</h2>
              <span className="text-[11px] text-slate-400">{g.hint}</span>
            </div>
            <div className="mt-2 grid grid-cols-1 gap-2.5 sm:grid-cols-2 xl:grid-cols-3">
              {g.boards.map((b) => (
                <Link
                  key={b.code}
                  to={b.path}
                  className="group flex items-center gap-3 rounded-2xl border border-slate-200 bg-white p-3 transition-all hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-md"
                >
                  <span className={cn('grid h-10 w-10 shrink-0 place-items-center rounded-xl ring-1', b.accent)}>
                    {b.icon}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-1.5">
                      <span className="font-mono text-[10px] font-semibold text-slate-400">{b.code}</span>
                      <span className="text-sm font-semibold text-slate-900">{b.title}</span>
                    </span>
                    <span className="block truncate text-[11px] text-slate-500">{b.desc}</span>
                  </span>
                  <span className="shrink-0 text-[10px] text-slate-400">{b.flow}</span>
                  <ArrowRight className="h-3.5 w-3.5 shrink-0 text-slate-300 transition-transform group-hover:translate-x-0.5 group-hover:text-blue-500" />
                </Link>
              ))}
            </div>
          </section>
        ))}

        <section className="mt-5">
          <h2 className="text-sm font-semibold text-slate-900">交付验收</h2>
          <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
            {[
              { icon: <Download className="h-4 w-4" />, text: '按住说话在屏幕下 1/4，不遮状态条' },
              { icon: <Mic className="h-4 w-4" />, text: '收音开始到波形跳动 < 100 ms' },
              { icon: <CircleSlash2 className="h-4 w-4" />, text: '断网 / 蓝牙关闭 / Mac 未授权 / 输入框缺失都有界面' },
              { icon: <SquarePen className="h-4 w-4" />, text: '可点击元素 ≥ 48 dp，状态不只靠颜色' },
            ].map((t) => (
              <div
                key={t.text}
                className="flex min-h-[52px] items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-[11px] text-slate-600"
              >
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-slate-100 text-slate-500">
                  {t.icon}
                </span>
                {t.text}
              </div>
            ))}
          </div>
        </section>
      </ScrollArea>
    </div>
  )
}
