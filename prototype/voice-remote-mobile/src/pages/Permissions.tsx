import { useNavigate } from 'react-router-dom'
import {
  Bluetooth,
  CheckCircle2,
  Mic,
  ShieldAlert,
  TriangleAlert,
  Wifi,
} from 'lucide-react'
import { cn } from '../lib/utils'
import { PERMISSION_META, useVoice, type PermissionKey, type PermissionStatus } from '../store/voice'
import { PhoneScreen, ScrollArea } from '../components/PhoneScreen'
import { Badge } from '../components/ui/badge'
import { Button } from '../components/ui/button'

const ICONS: Record<PermissionKey, React.ReactNode> = {
  microphone: <Mic className="h-5 w-5" />,
  localNetwork: <Wifi className="h-5 w-5" />,
  bluetooth: <Bluetooth className="h-5 w-5" />,
}

function StatusChip({ status }: { status: PermissionStatus }) {
  if (status === 'granted')
    return (
      <Badge variant="success">
        <CheckCircle2 className="h-3 w-3" /> 已授权
      </Badge>
    )
  if (status === 'denied')
    return (
      <Badge variant="danger">
        <ShieldAlert className="h-3 w-3" /> 已拒绝
      </Badge>
    )
  return (
    <Badge variant="warning">
      <TriangleAlert className="h-3 w-3" /> 待授权
    </Badge>
  )
}

export default function Permissions() {
  const { permissions, setPermission, grantAll } = useVoice()
  const navigate = useNavigate()
  const micOk = permissions.microphone === 'granted'

  const keys: PermissionKey[] = ['microphone', 'localNetwork', 'bluetooth']

  return (
    <PhoneScreen code="M-02" title="首次启动 · 权限">
      <ScrollArea className="px-4 pb-4 pt-4">
        <div className="flex items-center justify-between">
          <div className="text-xs font-semibold text-slate-500">
            第 2 步 / 共 3 步
          </div>
          <button
            type="button"
            onClick={grantAll}
            className="rounded-lg px-2 py-1 text-[11px] font-medium text-blue-700 hover:bg-blue-50"
          >
            全部允许（演示）
          </button>
        </div>
        <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-200">
          <div className="h-full w-2/3 rounded-full bg-blue-600 transition-all duration-500" />
        </div>
        <h1 className="mt-5 text-xl font-semibold tracking-tight text-slate-900">还差几个权限</h1>
        <p className="mt-1 text-sm text-slate-500">只开必要的，随时能在系统设置里关掉。</p>

        <ul className="mt-4 space-y-3">
          {keys.map((key) => {
            const meta = PERMISSION_META[key]
            const status = permissions[key]
            const granted = status === 'granted'
            return (
              <li
                key={key}
                className={cn(
                  'rounded-2xl border p-4 transition-all duration-200',
                  granted
                    ? 'border-emerald-200 bg-emerald-50/60'
                    : status === 'denied'
                      ? 'border-rose-200 bg-rose-50/40'
                      : 'border-slate-200 bg-white',
                )}
              >
                <div className="flex items-start gap-3">
                  <span
                    className={cn(
                      'grid h-10 w-10 shrink-0 place-items-center rounded-xl',
                      granted
                        ? 'bg-emerald-600 text-white'
                        : status === 'denied'
                          ? 'bg-rose-500 text-white'
                          : 'bg-slate-100 text-slate-500',
                    )}
                  >
                    {granted ? <CheckCircle2 className="h-5 w-5" /> : ICONS[key]}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h2 className="text-sm font-semibold text-slate-900">{meta.title}</h2>
                      {meta.required ? null : (
                        <span className="text-[10px] font-medium text-slate-400">可跳过</span>
                      )}
                    </div>
                    <p className="mt-0.5 text-xs text-slate-600">{meta.hint}</p>
                    <p className="mt-1 text-[11px] leading-relaxed text-slate-500">{meta.why}</p>
                  </div>
                  <StatusChip status={status} />
                </div>

                <div className="mt-3 flex items-center justify-between gap-2">
                  {status === 'denied' ? (
                    <span className="text-[11px] text-rose-700">设置 › 隐私 › {meta.title}</span>
                  ) : (
                    <span className="text-[11px] text-slate-400">
                      {granted ? '已开启，点右侧按钮可关闭' : '点按钮后系统会弹出询问'}
                    </span>
                  )}
                  {status === 'denied' ? (
                    <Button
                      size="sm"
                      variant="outline"
                      className="h-10 border-rose-200 text-rose-700 hover:bg-rose-50"
                      onClick={() => setPermission(key, 'granted')}
                    >
                      去系统设置
                    </Button>
                  ) : granted ? (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-10 text-slate-500"
                      onClick={() => setPermission(key, 'unknown')}
                    >
                      撤销
                    </Button>
                  ) : (
                    <Button
                      size="sm"
                      className="h-10"
                      onClick={() =>
                        setPermission(key, key === 'bluetooth' ? 'granted' : 'granted')
                      }
                    >
                      允许
                    </Button>
                  )}
                </div>
              </li>
            )
          })}
        </ul>

        <div className="mt-4 rounded-xl bg-slate-100/80 p-3 text-[11px] leading-relaxed text-slate-600">
          拒了也没关系：去「设置 › 隐私」里可以重新打开，回来点一下就会变勾选态。
        </div>
        <div className="h-4" />
      </ScrollArea>

      <div className="shrink-0 border-t border-slate-200/70 bg-white/90 px-4 pb-7 pt-3">
        <Button size="lg" className="w-full" disabled={!micOk} onClick={() => navigate('/m03')}>
          {micOk ? '下一步' : '麦克风未授权，下一步不可用'}
        </Button>
      </div>
    </PhoneScreen>
  )
}


