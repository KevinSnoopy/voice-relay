import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppWindow, ArrowLeftRight, Clock3, CornerDownLeft, Focus, FolderSearch, Laptop, Mic, Waves } from 'lucide-react'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { StatusBar } from './StatusBar'
import { Waveform } from './Waveform'
import { HoldButton } from './HoldButton'
import { PhoneScreen, ScrollArea } from './PhoneScreen'
import { Badge } from './ui/badge'
import { Button } from './ui/button'
import { formatDistanceToNow } from 'date-fns'
import { zhCN } from 'date-fns/locale'

export function VoiceHomeScreen() {
  const { last, backend, macName, activeApp, setConnected, saveLast, connected, setErrorMode } = useVoice()
  const [message, setMessage] = useState('')
  const navigate = useNavigate()

  useEffect(() => {
    setConnected(true)
  }, [setConnected])

  useEffect(() => {
    if (!message) return
    const timer = window.setTimeout(() => setMessage(''), 2000)
    return () => window.clearTimeout(timer)
  }, [message])

  const handleRecognized = (text: string) => {
    saveLast(text, 'success', undefined, '备忘录 · 项目周报')
    navigate('/m08')
  }

  return (
    <PhoneScreen code="M-05" title="语音主屏 · 已连接">
      <StatusBar
        state="connected"
        macName={macName}
        backend={backend}
        className="border-b border-slate-200/70 bg-white/80 backdrop-blur dark:border-slate-800 dark:bg-slate-950/70"
      />

      <ScrollArea className="px-4 pt-4">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold leading-tight text-slate-900 dark:text-slate-50">
            按住说话，字出现在 Mac 上
          </h1>
          <Badge variant="muted" className="shrink-0 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-300">
            <Clock3 className="h-3 w-3" /> 示例延迟 0.3 秒
          </Badge>
        </div>

        {last.delivered === 'success' && last.text ? (
          <button
            type="button"
            onClick={() => navigate('/m08')}
            className="mt-4 w-full rounded-2xl border border-slate-200 bg-white p-3.5 text-left shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition hover:border-blue-200 hover:shadow-md dark:border-slate-700 dark:bg-slate-900 dark:hover:border-blue-500/60"
          >
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-medium text-slate-500 dark:text-slate-400">
                最近一条 · {last.target ?? '备忘录'}
              </span>
              <span className="text-[11px] text-slate-400 dark:text-slate-500">
                {formatDistanceToNow(last.createdAt, { addSuffix: true, locale: zhCN })}
              </span>
            </div>
            <p className="mt-1.5 line-clamp-3 text-[15px] leading-relaxed text-slate-900 dark:text-slate-100">
              {last.text}
            </p>
            <span className="mt-2 inline-flex items-center gap-1 text-[11px] font-medium text-emerald-700 dark:text-emerald-400">
              已上屏 · 点开可复制
            </span>
          </button>
        ) : (
          <div className="mt-4 grid place-items-center rounded-2xl border border-dashed border-slate-300 bg-slate-50/60 px-4 py-8 text-center dark:border-slate-700 dark:bg-slate-900/50">
            <span className="grid h-14 w-14 place-items-center rounded-2xl bg-white text-slate-400 shadow-sm ring-1 ring-slate-200 dark:bg-slate-800 dark:text-slate-400 dark:ring-slate-700">
              <Waves className="h-6 w-6" />
            </span>
            <p className="mt-3 text-sm font-semibold text-slate-900 dark:text-slate-100">还没有上过屏</p>
            <p className="mt-1 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
              按住下面的按钮说一句话，<br className="hidden" />
              字会直接出现在 Mac 光标处。
            </p>
          </div>
        )}

        <div className="mt-4 flex items-center gap-2 rounded-xl bg-slate-100/80 p-2.5 text-[11px] text-slate-600 dark:bg-slate-800/70 dark:text-slate-300">
          <FolderSearch className="h-3.5 w-3.5 shrink-0" />
          光标在「{activeApp} · 项目周报」第 3 段
        </div>

        <div className="mt-4 rounded-2xl border border-slate-200 bg-white p-3.5 shadow-[0_1px_2px_rgba(15,23,42,0.04)] dark:border-slate-700 dark:bg-slate-900">
          <div className="flex items-center gap-2">
            <Laptop className="h-4 w-4 text-blue-600" />
            <span className="text-xs font-semibold text-slate-900 dark:text-slate-100">Mac 快捷控制</span>
            <span className="ml-auto text-[10px] text-emerald-700 dark:text-emerald-400">演示已连接</span>
          </div>
          <div className="mt-2 text-[11px] text-slate-500 dark:text-slate-400">当前 App：{activeApp} · 光标已就绪</div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            {[
              { label: '上一个 App', key: '⌘⇧Tab', icon: <ArrowLeftRight className="h-4 w-4" /> },
              { label: '下一个 App', key: '⌘Tab', icon: <ArrowLeftRight className="h-4 w-4" /> },
              { label: '下一个窗口', key: '⌘`', icon: <AppWindow className="h-4 w-4" /> },
              { label: '激活光标', key: '聚焦', icon: <Focus className="h-4 w-4" /> },
              { label: 'Shift+回车', key: '⇧↵', icon: <CornerDownLeft className="h-4 w-4" /> },
              { label: '回车发送', key: '↵', icon: <CornerDownLeft className="h-4 w-4" /> },
            ].map((action) => (
              <button
                key={action.label}
                type="button"
                onClick={() => setMessage(`演示：已发送 ${action.label}`)}
                className="flex min-h-[68px] flex-col items-center justify-center rounded-xl border border-slate-200 bg-slate-50 px-1 text-slate-700 transition hover:border-blue-300 hover:bg-blue-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:hover:border-blue-500"
              >
                {action.icon}
                <span className="mt-1.5 text-[10px] font-medium">{action.label}</span>
                <span className="mt-0.5 text-[9px] text-slate-400">{action.key}</span>
              </button>
            ))}
          </div>
          {message ? <p className="mt-2 text-[10px] text-blue-700 dark:text-blue-400">{message}</p> : null}
        </div>
      </ScrollArea>

      <div className="flex shrink-0 flex-col items-center pb-6 pt-1">
        <Waveform active={false} height={96} className="w-full" />
        <HoldButton
          className="-mt-2"
          disabled={!connected}
          onRecognized={handleRecognized}
          onTimeout={() => {
            setErrorMode('timeout')
            navigate('/m09')
          }}
        />
      </div>
    </PhoneScreen>
  )
}

void Mic
void Button
void cn
