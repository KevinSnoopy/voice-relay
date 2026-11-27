import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, Flashlight, QrCode, Search } from 'lucide-react'
import { cn } from '../lib/utils'
import { useVoice } from '../store/voice'
import { PhoneScreen } from '../components/PhoneScreen'
import { Button } from '../components/ui/button'
import { Badge } from '../components/ui/badge'

export default function ScanPair() {
  const [scanned, setScanned] = useState(false)
  const { pair } = useVoice()
  const navigate = useNavigate()

  useEffect(() => {
    if (!scanned) return
    const id = window.setTimeout(() => navigate('/m05'), 1400)
    return () => clearTimeout(id)
  }, [scanned, navigate])

  return (
    <PhoneScreen code="M-04" title="二维码配对" tone="dark" homeIndicator>
      <div className="relative flex min-h-0 flex-1 flex-col overflow-hidden bg-slate-950 text-slate-50">
        {/* 相机预览背景（无外部图片，用真实相机构图感的光斑） */}
        <div
          aria-hidden
          className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(56,189,248,0.35),transparent_45%),radial-gradient(circle_at_75%_65%,rgba(99,102,241,0.35),transparent_50%),radial-gradient(circle_at_20%_85%,rgba(14,165,233,0.25),transparent_45%)]"
        />
        <div
          aria-hidden
          className="absolute inset-0 opacity-[0.14] [background-image:linear-gradient(rgba(255,255,255,.4)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.4)_1px,transparent_1px)] [background-size:36px_36px]"
        />

        <div className="relative flex shrink-0 items-center justify-between px-4 pt-4">
          <Badge className="border-white/20 bg-white/10 text-white backdrop-blur">
            <QrCode className="h-3 w-3" /> 相机已开启
          </Badge>
          <button
            type="button"
            aria-label="打开闪光灯"
            className="grid h-11 w-11 place-items-center rounded-full bg-white/10 text-white backdrop-blur transition hover:bg-white/20"
          >
            <Flashlight className="h-5 w-5" />
          </button>
        </div>

        <div className="relative flex flex-1 flex-col items-center justify-center px-6">
          <div className="relative h-[248px] w-[248px]">
            {[
              'left-0 top-0 border-l-2 border-t-2 rounded-tl-xl',
              'right-0 top-0 border-r-2 border-t-2 rounded-tr-xl',
              'left-0 bottom-0 border-l-2 border-b-2 rounded-bl-xl',
              'right-0 bottom-0 border-r-2 border-b-2 rounded-br-xl',
            ].map((c) => (
              <span
                key={c}
                className={cn(
                  'absolute h-9 w-9 border-white',
                  c,
                  scanned && 'border-emerald-400',
                )}
              />
            ))}
            <div className="absolute inset-4 grid place-items-center rounded-lg bg-white/5">
              {scanned ? (
                <div className="flex flex-col items-center gap-2 text-emerald-300">
                  <CheckCircle2 className="h-12 w-12" />
                  <span className="text-sm font-semibold text-white">已识别 · Studio 设计台</span>
                </div>
              ) : (
                <div className="grid h-[120px] w-[120px] grid-cols-5 grid-rows-5 gap-1 opacity-70">
                  {Array.from({ length: 25 }).map((_, i) => (
                    <span
                      key={i}
                      className={cn(
                        'rounded-[2px]',
                        [0, 1, 2, 5, 7, 10, 12, 14, 17, 18, 20, 22, 24].includes(i)
                          ? 'bg-white/85'
                          : 'bg-white/10',
                      )}
                    />
                  ))}
                </div>
              )}
            </div>
            {!scanned && (
              <span className="absolute inset-x-4 top-4 h-0.5 rounded-full bg-cyan-300/90 shadow-[0_0_18px_4px_rgba(103,232,249,0.6)] scanner-line" />
            )}
          </div>
          <p className="mt-6 text-center text-sm font-medium text-white">
            {scanned ? '配对成功，正在连接…' : '对准 Mac 屏幕上的二维码'}
          </p>
          <p className="mt-1 text-center text-xs text-slate-300">
            Mac 端：菜单栏图标 › 配对 › 显示二维码
          </p>
        </div>

        <div className="relative shrink-0 space-y-2 px-5 pb-8 pt-3">
          <Button
            size="lg"
            className="w-full bg-white text-slate-900 hover:bg-slate-100"
            onClick={() => {
              pair('Studio · 设计台')
              setScanned(true)
            }}
          >
            {scanned ? '已配对' : '模拟扫描成功'}
          </Button>
          <button
            type="button"
            onClick={() => navigate('/m03')}
            className="flex min-h-[48px] w-full items-center justify-center gap-1.5 text-xs font-medium text-slate-300 hover:text-white"
          >
            <Search className="h-4 w-4" />
            改用自动发现
          </button>
        </div>
      </div>
    </PhoneScreen>
  )
}
