import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { LifeBuoy, QrCode, RefreshCw, Radar } from 'lucide-react'
import { cn } from '../lib/utils'
import { MAC_LIST, useVoice } from '../store/voice'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Button } from '../components/ui/button'
import { Badge } from '../components/ui/badge'

type Mode = 'searching' | 'found' | 'empty' | 'failed'

export default function Discover() {
  const [mode, setMode] = useState<Mode>('searching')
  const [elapsed, setElapsed] = useState(0)
  const { pair } = useVoice()
  const navigate = useNavigate()

  useEffect(() => {
    if (mode !== 'searching') return
    const id = window.setInterval(() => {
      setElapsed((e) => {
        const next = e + 1
        if (next >= 4) setMode('found')
        if (next >= 15) setMode((m) => (m === 'searching' ? 'empty' : m))
        return next
      })
    }, 1000)
    return () => clearInterval(id)
  }, [mode])

  useEffect(() => {
    if (mode !== 'searching') return
    const id = window.setTimeout(() => setMode('found'), 1600)
    return () => clearTimeout(id)
  }, [mode])

  const pick = (name: string) => {
    pair(name)
    navigate('/m05')
  }

  return (
    <PhoneScreen code="M-03" title="搜索 Mac">
      <ScrollArea className="px-4 pt-6">
        <div className="relative mx-auto grid h-40 w-40 place-items-center">
          {['0s', '0.9s', '1.8s'].map((d) => (
            <span
              key={d}
              className="radar-ring absolute rounded-full border border-blue-400/60"
              style={{ animationDelay: d }}
            />
          ))}
          <span className="relative grid h-20 w-20 place-items-center rounded-full bg-gradient-to-b from-blue-500 to-blue-700 text-white shadow-[0_18px_40px_-16px_rgba(37,99,235,0.9)]">
            <Radar className={cn('h-9 w-9', mode === 'searching' && 'animate-spin-slow')} />
          </span>
        </div>

        <h1 className="mt-5 text-center text-lg font-semibold text-slate-900">
          {mode === 'searching'
            ? '正在查找你的 Mac'
            : mode === 'found'
              ? `找到 ${MAC_LIST.length} 台 Mac`
              : mode === 'empty'
                ? '没找到附近的 Mac'
                : '搜索失败了'}
        </h1>
        <p className="mx-auto mt-1 max-w-[280px] text-center text-xs leading-relaxed text-slate-500">
          {mode === 'searching'
            ? '确保 Mac 已打开配套 App，并和手机连同一个 Wi-Fi。'
            : mode === 'found'
              ? '选一台连接。第一次连需要确认一次。'
              : mode === 'empty'
                ? '检查 Wi-Fi 是否一致，或改用扫码连接。'
                : '网络好像断了，恢复后点重试。'}
        </p>

        <div className="mt-5">
          {mode === 'searching' && (
            <ul className="space-y-2.5">
              {[0, 1, 2].map((i) => (
                <li
                  key={i}
                  className="h-[66px] animate-pulse rounded-2xl border border-slate-200 bg-white"
                  style={{ opacity: 1 - i * 0.22 }}
                />
              ))}
            </ul>
          )}

          {mode === 'found' && (
            <ul className="space-y-2.5">
              {MAC_LIST.map((m) => (
                <li key={m.id}>
                  <button
                    type="button"
                    onClick={() => pick(m.name)}
                    className="flex min-h-[66px] w-full items-center gap-3 rounded-2xl border border-slate-200 bg-white p-3 text-left transition-all hover:border-blue-300 hover:shadow-md active:scale-[0.99]"
                  >
                    <span className="grid h-10 w-10 place-items-center rounded-xl bg-slate-900 text-[10px] font-bold text-white">
                      Mac
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-semibold text-slate-900">
                        {m.name}
                      </span>
                      <span className="block text-[11px] text-slate-500">{m.detail}</span>
                    </span>
                    <span className="flex items-end gap-[3px]" aria-label={`信号 ${m.strength} 格`}>
                      {[1, 2, 3, 4].map((i) => (
                        <span
                          key={i}
                          className={cn(
                            'w-[3px] rounded-full',
                            i <= m.strength ? 'bg-emerald-500' : 'bg-slate-200',
                          )}
                          style={{ height: 4 + i * 3 }}
                        />
                      ))}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}

          {(mode === 'empty' || mode === 'failed') && (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center">
              <p className="text-sm font-semibold text-slate-900">
                {mode === 'empty' ? '同一网络里还没有 Mac' : '没有连上网络'}
              </p>
              <p className="mt-1 text-xs leading-relaxed text-slate-500">
                {mode === 'empty'
                  ? '在 Mac 上打开配套 App，或在 Mac 设置里打开「屏幕录制」。'
                  : '打开 Wi-Fi 后点重试，或改用扫码连接。'}
              </p>
              <Button
                variant="outline"
                className="mt-3 h-10 border-slate-200"
                onClick={() => {
                  setElapsed(0)
                  setMode('searching')
                }}
              >
                <RefreshCw className="h-4 w-4" />
                重新搜索
              </Button>
            </div>
          )}
        </div>

        <div className="mt-3 flex justify-center gap-2">
          <button
            type="button"
            onClick={() => setMode('found')}
            className="rounded-lg px-2 py-1 text-[11px] text-slate-400 hover:bg-slate-100"
          >
            演示：找到
          </button>
          <button
            type="button"
            onClick={() => setMode('empty')}
            className="rounded-lg px-2 py-1 text-[11px] text-slate-400 hover:bg-slate-100"
          >
            演示：0 个
          </button>
          <button
            type="button"
            onClick={() => setMode('failed')}
            className="rounded-lg px-2 py-1 text-[11px] text-slate-400 hover:bg-slate-100"
          >
            演示：失败
          </button>
        </div>
        <div className="h-4" />
      </ScrollArea>

      <div className="shrink-0 space-y-1 px-4 pb-7 pt-2">
        <Button
          variant="outline"
          size="lg"
          className="w-full border-slate-200"
          onClick={() => navigate('/m04')}
        >
          <QrCode className="h-4 w-4" />
          扫码连接
        </Button>
        <Link
          to="/m12"
          className="flex min-h-[48px] items-center justify-center gap-1.5 text-xs font-medium text-slate-500 hover:text-slate-800"
        >
          <LifeBuoy className="h-4 w-4" />
          找不到？查看排查
        </Link>
      </div>
    </PhoneScreen>
  )
}

void Badge
