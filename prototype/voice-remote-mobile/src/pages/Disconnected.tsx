import { Link, useNavigate } from 'react-router-dom'
import { ChevronRight, Mic, MonitorSmartphone, QrCode, Radar, WifiOff } from 'lucide-react'
import { MAC_LIST, useVoice } from '../store/voice'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { StatusBar } from '../components/StatusBar'
import { Waveform } from '../components/Waveform'
import { HoldButton } from '../components/HoldButton'
import { Button } from '../components/ui/button'
import { Badge } from '../components/ui/badge'

export default function Disconnected() {
  const { macName, last } = useVoice()
  const navigate = useNavigate()

  return (
    <PhoneScreen code="M-13" title="未连接空态">
      <StatusBar state="disconnected" macName="还没有设备" backend="local" />

      <ScrollArea className="px-4 pt-6">
        <div className="grid place-items-center rounded-3xl border border-dashed border-slate-300 bg-slate-50/70 px-5 py-8 text-center">
          <span className="relative grid h-20 w-20 place-items-center rounded-full bg-white text-slate-400 shadow-sm ring-1 ring-slate-200">
            <MonitorSmartphone className="h-8 w-8" />
            <span className="absolute -bottom-1 -right-1 grid h-7 w-7 place-items-center rounded-full bg-slate-200 text-slate-500">
              <WifiOff className="h-3.5 w-3.5" />
            </span>
          </span>
          <h1 className="mt-4 text-lg font-semibold text-slate-900">还没连上 Mac</h1>
          <p className="mt-1 max-w-[260px] text-xs leading-relaxed text-slate-500">
            连上之后按住下面的按钮，说的话就会出现在 Mac 光标处。
          </p>
        </div>

        <div className="mt-4 space-y-2">
          <Button size="lg" className="w-full" onClick={() => navigate('/m03')}>
            <Radar className="h-4 w-4" /> 搜索附近的 Mac
          </Button>
          <Button
            variant="outline"
            size="lg"
            className="w-full border-slate-200"
            onClick={() => navigate('/m04')}
          >
            <QrCode className="h-4 w-4" /> 扫码连接
          </Button>
        </div>

        {last.text && (
          <div className="mt-4 rounded-2xl border border-slate-200 bg-white p-3.5">
            <div className="flex items-center justify-between text-[11px]">
              <span className="font-medium text-slate-500">上次说过的话</span>
              <Badge variant="muted">{last.target ?? '备忘录'}</Badge>
            </div>
            <p className="mt-1.5 line-clamp-2 text-sm leading-relaxed text-slate-700">{last.text}</p>
            <p className="mt-1 text-[11px] text-slate-400">连上后可以接着用，不会丢</p>
          </div>
        )}

        <div className="mt-3 rounded-2xl border border-slate-200 bg-white">
          <div className="px-3.5 pt-3 text-[11px] font-semibold text-slate-700">可连接的 Mac</div>
          <div className="mt-1 divide-y divide-slate-100">
            {MAC_LIST.slice(0, 2).map((m) => (
              <Link
                key={m.id}
                to="/m03"
                className="flex min-h-[52px] items-center gap-2 px-3.5 text-xs text-slate-700 hover:bg-slate-50"
              >
                <span className="h-1.5 w-1.5 rounded-full bg-amber-500" />
                <span className="flex-1 truncate">{m.name}</span>
                <span className="text-[10px] text-slate-400">离线</span>
                <ChevronRight className="h-3.5 w-3.5 text-slate-300" />
              </Link>
            ))}
          </div>
        </div>
        <div className="h-4" />
      </ScrollArea>

      <div className="flex shrink-0 flex-col items-center pb-8 pt-2">
        <Waveform active={false} height={72} className="w-full opacity-70" />
        <HoldButton
          disabled
          onRecognized={() => undefined}
          onTimeout={() => undefined}
        />
        <p className="mt-1 flex items-center gap-1 text-[11px] text-slate-500">
          <Mic className="h-3.5 w-3.5" /> 连上 Mac 后按钮才能用
        </p>
      </div>

      <span className="sr-only">{macName}</span>
    </PhoneScreen>
  )
}
